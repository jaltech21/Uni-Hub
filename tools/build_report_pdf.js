const fs = require("fs");
const path = require("path");
const { PassThrough } = require("stream");
const PDFDocument = require("pdfkit");
const SVGtoPDF = require("svg-to-pdfkit");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "docs/UNIMTECH_UniHub_Project_Report.md"), "utf8");
const output = path.join(root, "docs/UNIMTECH_UniHub_Project_Report.pdf");
const regularFont = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";
const boldFont = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf";

function renderReport(destination, tocEntries, headingPages) {
  const doc = new PDFDocument({
    size: "A4",
    margin: 72,
    bufferPages: true,
    info: { Title: "UniHub UNIMTECH Project Report" },
  });
  const stream = destination ? fs.createWriteStream(destination) : new PassThrough();
  doc.pipe(stream);

  function footer() {
    const range = doc.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i += 1) {
      doc.switchToPage(i);
      doc.font(regularFont).fontSize(8).fillColor("#555555")
        .text(`UniHub Project Report | Page ${i + 1}`, 72, 770, { align: "center", width: 451 });
    }
  }

  function addParagraph(text, size = 12, gap = 8) {
    doc.font(regularFont).fontSize(size).fillColor("#111111").text(text.replace(/\*\*/g, ""), {
      align: "left", lineGap: 6, paragraphGap: gap,
    });
  }

  let dividerCount = 0;
  let inToc = false;
  const blocks = source.split(/\r?\n\s*\r?\n/);
  const currentPageNumber = () => {
    const range = doc.bufferedPageRange();
    return range.start + range.count;
  };
  for (const block of blocks) {
    const lines = block.split(/\r?\n/).map((item) => item.trim()).filter(Boolean);
    if (!lines.length) continue;
    const line = lines[0];
    if (inToc && !line.startsWith("# ") && !line.startsWith("## ") && line !== "---") continue;
    if (line === "---") {
      inToc = false;
      dividerCount += 1;
      if (dividerCount <= 2) {
        doc.addPage();
      } else {
        doc.moveDown(0.4);
      }
    } else if (line === "# Table of Contents") {
      inToc = true;
      doc.font(boldFont).fontSize(20).fillColor("#111111")
        .text("Table of Contents", { align: "center", paragraphGap: 18 });
      for (const entry of tocEntries) {
        addParagraph(`${entry.label} ................................ ${entry.page}`, 11, 3);
      }
    } else if (line.startsWith("# ")) {
      const heading = line.slice(2);
      if (heading === "1. Project Overview") inToc = false;
      if (headingPages && !headingPages[heading]) headingPages[heading] = currentPageNumber();
      doc.font(boldFont).fontSize(20).fillColor("#111111")
        .text(heading, { align: "center", paragraphGap: 18 });
    } else if (line.startsWith("## ")) {
      const heading = line.slice(3);
      if (headingPages && !headingPages[heading]) headingPages[heading] = currentPageNumber();
      doc.font(boldFont).fontSize(14).fillColor("#111111")
        .text(heading, { paragraphGap: 10 });
    } else if (line.startsWith("### ")) {
      doc.font(boldFont).fontSize(12).fillColor("#111111")
        .text(line.slice(4), { paragraphGap: 6 });
    } else if (line.startsWith("![") && line.includes("assets/")) {
      const imagePath = path.join(root, "docs", line.match(/\((.*?)\)/)[1]);
      if (fs.existsSync(imagePath)) {
        if (doc.y > 560) doc.addPage();
        if (imagePath.endsWith(".svg")) {
          SVGtoPDF(doc, fs.readFileSync(imagePath, "utf8"), 122, doc.y, { width: 350, height: 181 });
          doc.y += 300;
        } else {
          doc.image(imagePath, { fit: [430, 100], align: "center" });
        }
        doc.moveDown(0.5);
      }
    } else if (line.startsWith("|")) {
      for (const tableLine of lines) {
        const cells = tableLine.split("|").slice(1, -1).map((cell) => cell.trim());
        if (cells.length && !cells.every((cell) => /^[-:]+$/.test(cell))) {
          addParagraph(cells.join("   |   "), 9, 4);
        }
      }
    } else if (line.startsWith("- ") || /^\d+\. /.test(line)) {
      for (const listLine of lines) {
        addParagraph(`• ${listLine.replace(/^(- |\d+\. )/, "")}`, 11, 4);
      }
    } else {
      addParagraph(lines.join(" "));
    }
  }

  footer();
  doc.end();
  return doc;
}

const headings = [];
let reportBodyStarted = false;
for (const line of source.split(/\r?\n/)) {
  if (line === "# 1. Project Overview") reportBodyStarted = true;
  if (reportBodyStarted && (/^# (.+)$/.test(line) || /^## (.+)$/.test(line))) {
    headings.push({ label: line.replace(/^##? /, "").trim(), page: "..." });
  }
}

const firstPassPages = {};
renderReport(null, headings, firstPassPages);
const resolvedEntries = headings.map((entry) => ({ ...entry, page: firstPassPages[entry.label] || "?" }));
renderReport(output, resolvedEntries, null);
console.log(output);
