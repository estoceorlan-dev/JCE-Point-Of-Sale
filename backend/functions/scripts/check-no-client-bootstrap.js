const fs = require("node:fs");
const path = require("node:path");

const sourceRoots = [
  path.resolve(__dirname, "..", "src"),
  path.resolve(__dirname, "..", "..", "..", "lib"),
];
const sourceExtensions = new Set([".dart", ".ts"]);
const forbiddenPatterns = [
  /AdminBootstrap/,
  /bootstrapAdmin/,
  /bootstrapTemporaryAdmin/,
  /JCE_ADMIN_BOOTSTRAP_FUNCTION/,
];

function sourceFiles(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return sourceFiles(entryPath);
    }
    return sourceExtensions.has(path.extname(entry.name)) ? [entryPath] : [];
  });
}

const violations = sourceRoots.flatMap((root) =>
  sourceFiles(root).flatMap((file) => {
    const source = fs.readFileSync(file, "utf8");
    return forbiddenPatterns
      .filter((pattern) => pattern.test(source))
      .map((pattern) => `${path.relative(process.cwd(), file)}: ${pattern}`);
  }),
);

if (violations.length > 0) {
  console.error("Client-callable admin bootstrap code is forbidden:");
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  process.exitCode = 1;
} else {
  console.log("No client-callable admin bootstrap code found.");
}
