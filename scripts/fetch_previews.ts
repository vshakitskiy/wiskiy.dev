// Fills in missing preview images for the featured work list.
//
//   deno task previews          fill in what is missing
//   deno task previews --force  refetch everything

const ISLAND = "web/src/web/islands/work.gleam";
const ASSETS = "web/priv/assets/work";
const RASTER = ["png", "jpg", "jpeg", "webp"];

type Project = {
  name: string;
  url: string;
  file: string;
  extension: string;
};

function projects(source: string): Project[] {
  // We are getting projects list straight from the gleam file. Kind of dirty 
  // work but this makes gleam records be the only source of truth!
  const block = source.match(/pub const projects = \[([\s\S]*?)\n\]/);
  if (!block) throw new Error(`no 'pub const projects' found in ${ISLAND}`);

  const found: Project[] = [];
  const entry =
    /name:\s*"([^"]+)"[\s\S]*?url:\s*"([^"]+)"[\s\S]*?media:\s*(?:Image|Video)\("\/work\/([^"]+)"\)/g;

  for (const [, name, url, file] of block[1].matchAll(entry)) {
    found.push({ name, url, file, extension: file.split(".").pop() ?? "" });
  }
  return found;
}

async function shoot(project: Project): Promise<Uint8Array> {
  const endpoint = new URL("https://api.microlink.io/");
  endpoint.searchParams.set("url", project.url);
  endpoint.searchParams.set("screenshot", "true");
  endpoint.searchParams.set("meta", "false");
  endpoint.searchParams.set("embed", "screenshot.url");
  endpoint.searchParams.set("colorScheme", "dark");
  endpoint.searchParams.set("viewport.width", "1280");
  endpoint.searchParams.set("viewport.height", "800");

  const response = await fetch(endpoint);
  if (!response.ok) {
    throw new Error(`microlink answered ${response.status}`);
  }
  return new Uint8Array(await response.arrayBuffer());
}

const force = Deno.args.includes("--force");
const source = await Deno.readTextFile(ISLAND);
const found = projects(source);

if (found.length === 0) {
  console.error("no projects parsed!");
  Deno.exit(1);
}

let failures = 0;

const results = await Promise.allSettled(found.map(async (project) => {
  const out = `${ASSETS}/${project.file}`;

  if (!RASTER.includes(project.extension)) {
    console.log(
      `skipping ${project.name}, ${project.file} is not a screenshot format.`
    );
    return;
  }

  if (!force) {
    const existing = await Deno.stat(out).catch(() => null);
    if (existing) {
      console.log(`skipping ${project.name}, ${project.file} already exists`);
      return;
    }
  }

  console.log(`shooting ${project.name} from ${project.url}`);
  await Deno.writeFile(out, await shoot(project));
  console.log(`wrote ${out}`);
}));

for (const result of results) {
  if (result.status === "rejected") {
    failures += 1;
    console.error(String(result.reason));
  }
}

if (failures > 0) {
  console.error(`${failures} preview(s) failed`);
  Deno.exit(1);
}
