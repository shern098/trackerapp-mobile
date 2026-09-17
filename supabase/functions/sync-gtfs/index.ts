import { createClient } from 'jsr:@supabase/supabase-js@2';
import { unzipSync } from 'npm:fflate@0.8.2';
import Papa from 'npm:papaparse@5.4.1';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const VALID_CATEGORIES = [
  'rapid-bus-kl',
  'rapid-bus-penang',
  'rapid-bus-kuantan',
  'rapid-bus-mrtfeeder',
  'rapid-rail-kl',
];

const FILE_CONFIG: Record<
  string,
  { table: string; map: (r: Record<string, string>, category: string) => any | null }
> = {
  agency: {
    table: 'gtfs_agencies',
    map: (r, category) => {
      if (!r.agency_id?.trim()) return null; // skip malformed rows
      return {
        feed_category: category,
        agency_id: r.agency_id,
        agency_name: r.agency_name,
        agency_url: r.agency_url,
        agency_timezone: r.agency_timezone,
      };
    },
  },
  routes: {
    table: 'gtfs_routes',
    map: (r, category) => {
      if (!r.route_id?.trim()) return null;
      return {
        feed_category: category,
        route_id: r.route_id,
        agency_id: r.agency_id,
        route_short_name: r.route_short_name,
        route_long_name: r.route_long_name,
        route_type: parseInt(r.route_type) || null,
        route_color: r.route_color,
        route_text_color: r.route_text_color,
      };
    },
  },
  stops: {
    table: 'gtfs_stops',
    map: (r, category) => {
      if (!r.stop_id?.trim()) return null;
      return {
        feed_category: category,
        stop_id: r.stop_id,
        stop_name: r.stop_name,
        stop_desc: r.stop_desc,
        stop_lat: parseFloat(r.stop_lat) || null,
        stop_lon: parseFloat(r.stop_lon) || null,
      };
    },
  },
  trips: {
    table: 'gtfs_trips',
    map: (r, category) => {
      if (!r.trip_id?.trim()) return null;
      return {
        feed_category: category,
        trip_id: r.trip_id,
        route_id: r.route_id,
        service_id: r.service_id,
        shape_id: r.shape_id,
        trip_headsign: r.trip_headsign,
        direction_id: r.direction_id,
      };
    },
  },
  shapes: {
    table: 'gtfs_shapes',
    map: (r, category) => {
      const seq = parseInt(r.shape_pt_sequence);
      if (!r.shape_id?.trim() || isNaN(seq)) return null;
      return {
        feed_category: category,
        shape_id: r.shape_id,
        shape_pt_sequence: seq,
        shape_pt_lat: parseFloat(r.shape_pt_lat) || null,
        shape_pt_lon: parseFloat(r.shape_pt_lon) || null,
      };
    },
  },
  stop_times: {
    table: 'gtfs_stop_times',
    map: (r, category) => {
      const seq = parseInt(r.stop_sequence);
      if (!r.trip_id?.trim() || isNaN(seq)) return null;
      return {
        feed_category: category,
        trip_id: r.trip_id,
        stop_id: r.stop_id,
        stop_sequence: seq,
      };
    },
  },
};

async function upsertInChunks(table: string, rows: any[], chunkSize = 500) {
  for (let i = 0; i < rows.length; i += chunkSize) {
    const { error } = await admin.from(table).upsert(rows.slice(i, i + chunkSize));
    if (error) throw new Error(`${table} upsert failed: ${error.message}`);
  }
}

// Detects which line ending this file actually uses, since different
// operators' export pipelines aren't consistent (\r\n, \n, or \r alone).
function detectLineEnding(text: string): string {
  const idx = text.indexOf('\n');
  if (idx > 0 && text[idx - 1] === '\r') return '\r\n';
  if (idx === -1 && text.indexOf('\r') !== -1) return '\r';
  return '\n';
}

// Extracts exactly the lines we need from bodyText, WITHOUT ever
// building an array of every line in the file first. This keeps
// memory bounded to the slice size, not the total file size --
// critical for files like Penang's 23MB stop_times.txt.
function extractLineSlice(
  bodyText: string,
  startLine: number,
  lineCount: number,
  lineEnding: string,
): { slice: string; hasMore: boolean } {
  let pos = 0;
  let line = 0;

  // Skip forward to the start line without storing anything.
  while (line < startLine) {
    const idx = bodyText.indexOf(lineEnding, pos);
    if (idx === -1) return { slice: '', hasMore: false };
    pos = idx + lineEnding.length;
    line++;
  }

  const startPos = pos;
  let endPos = pos;
  let collected = 0;

  while (collected < lineCount) {
    const idx = bodyText.indexOf(lineEnding, endPos);
    if (idx === -1) {
      endPos = bodyText.length;
      collected++;
      break;
    }
    endPos = idx + lineEnding.length;
    collected++;
  }

  return {
    slice: bodyText.slice(startPos, endPos),
    hasMore: endPos < bodyText.length,
  };
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const category = url.searchParams.get('category');
  const file = url.searchParams.get('file');
  const offset = parseInt(url.searchParams.get('offset') || '0');
  const limit = parseInt(url.searchParams.get('limit') || '0'); // 0 = no slicing, whole file

  if (!category || !VALID_CATEGORIES.includes(category)) {
    return new Response(
      JSON.stringify({ error: `Missing or invalid category. Valid: ${VALID_CATEGORIES.join(', ')}` }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  if (!file || !FILE_CONFIG[file]) {
    return new Response(
      JSON.stringify({ error: `Missing or invalid file. Valid: ${Object.keys(FILE_CONFIG).join(', ')}` }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  try {
    const zipUrl = `https://api.data.gov.my/gtfs-static/prasarana?category=${category}`;
    const res = await fetch(zipUrl);
    if (!res.ok) throw new Error(`Failed to fetch ${category}: ${res.status}`);

    const zipBytes = new Uint8Array(await res.arrayBuffer());

    // Only decompress the ONE file we need out of the whole archive.
    const files = unzipSync(zipBytes, {
      filter: (entry) => entry.name === `${file}.txt`,
    });

    const bytes = files[`${file}.txt`];
    if (!bytes) {
      return new Response(
        JSON.stringify({ [`${category}/${file}`]: 'skipped (file not in feed)' }),
        { headers: { 'Content-Type': 'application/json' } },
      );
    }

    const text = new TextDecoder().decode(bytes);
    const lineEnding = detectLineEnding(text);
    const headerEnd = text.indexOf(lineEnding);
    const header = headerEnd === -1 ? text : text.slice(0, headerEnd);
    const bodyText = headerEnd === -1 ? '' : text.slice(headerEnd + lineEnding.length);

    const { slice, hasMore } =
      limit > 0
        ? extractLineSlice(bodyText, offset, limit, lineEnding)
        : { slice: bodyText, hasMore: false };

    const sliceText = header + '\n' + slice;
    const { data } = Papa.parse(sliceText, { header: true, skipEmptyLines: true });

    const config = FILE_CONFIG[file];
    const rows = (data as Record<string, string>[])
      .map((r) => config.map(r, category))
      .filter((r) => r !== null);

    await upsertInChunks(config.table, rows);

    return new Response(
      JSON.stringify({
        [`${category}/${file}`]: `ok (${rows.length} rows, offset ${offset})`,
        hasMore,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ [`${category}/${file}`]: `error: ${err.message}` }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});