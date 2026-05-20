// Tailwind v4 plugin that turns class names like `hero-pencil-square`,
// `hero-trash-solid`, `hero-eye-mini` into CSS-mask icons sourced from the
// :heroicons Hex dep at deps/heroicons/optimized/.
//
// Conventions:
//   hero-<name>          → 24/outline/<name>.svg
//   hero-<name>-solid    → 24/solid/<name>.svg
//   hero-<name>-mini     → 20/solid/<name>.svg
//   hero-<name>-micro    → 16/solid/<name>.svg
const fs = require("fs");
const path = require("path");
const plugin = require("tailwindcss/plugin");

const iconsDir = path.join(
  __dirname,
  "..",
  "deps",
  "heroicons",
  "optimized"
);

const variants = [
  ["", "/24/outline"],
  ["-solid", "/24/solid"],
  ["-mini", "/20/solid"],
  ["-micro", "/16/solid"],
];

module.exports = plugin(function ({ matchComponents }) {
  const values = {};

  for (const [suffix, dir] of variants) {
    const fullDir = path.join(iconsDir, dir);
    if (!fs.existsSync(fullDir)) continue;
    fs.readdirSync(fullDir).forEach((file) => {
      const name = path.basename(file, ".svg") + suffix;
      values[name] = { name, fullPath: path.join(fullDir, file) };
    });
  }

  matchComponents(
    {
      hero: ({ name, fullPath }) => {
        let content = fs
          .readFileSync(fullPath)
          .toString()
          .replace(/\r?\n|\r/g, "");
        const size = name.endsWith("-mini")
          ? "20px"
          : name.endsWith("-micro")
            ? "16px"
            : "24px";
        return {
          [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${encodeURIComponent(
            content
          )}')`,
          "-webkit-mask": `var(--hero-${name})`,
          mask: `var(--hero-${name})`,
          "background-color": "currentColor",
          "vertical-align": "middle",
          display: "inline-block",
          width: size,
          height: size,
        };
      },
    },
    { values }
  );
});
