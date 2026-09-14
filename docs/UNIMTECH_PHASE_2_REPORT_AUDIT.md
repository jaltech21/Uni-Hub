# Phase 2: Report-to-Guideline Audit

Compared:

- [UNIMTECH guideline checklist](UNIMTECH_GUIDELINE_COMPLIANCE_CHECKLIST.md)
- [Current UniHub report](UNIMTECH_UniHub_Project_Report.md)
- Current generated PDF: 16 A4 pages

This phase is an audit only. No report content was edited during Phase 2.

## Executive result

The report has the correct high-level development-project sections and contains
substantial methodology content. It is not yet fully compliant with the
guideline because the table of contents lacks page numbers, the overview is too
long, several Chapter 2 figure placeholders remain, figure numbering is
inconsistent, and required personal/project metadata is still blank.

## Detailed comparison

| Guideline requirement | Current status | Evidence / gap |
|---|---|---|
| Required section order | Mostly compliant | Title page, contents, overview, methodology, product evaluation, reflection, conclusion, references, and appendices appear in order. |
| Development-project terminology | Compliant | The report uses “Project Execution / Development Methodology”, “Product Evaluation and Outcomes”, and “Analysis and Reflective Discussion”. |
| Approved project title | Needs input | The title is currently “UniHub: A Web and Mobile Academic Support Platform”; approval is not evidenced. |
| Student name and ID | Not compliant yet | Placeholders remain: `[Student name]` and `[Student ID]`. |
| Supervisor name | Not compliant yet | Placeholder remains: `[Supervisor name]`. |
| University and department | Partially compliant | UNIMTECH and Department of Computer Science are present; department must be confirmed against the student's programme. |
| Submission date | Needs confirmation | A date is present, but it must match the actual submission date. |
| Accurate table of contents page numbers | Not compliant yet | Contents lists headings but no page numbers. |
| Overview topic in 2–3 sentences | Partially compliant | The topic is clear, but the overview uses more than three sentences. |
| Overview objective | Compliant | The objective is stated clearly. |
| Overview approach | Compliant | Incremental development and testing approach are stated. |
| Overview length 150–200 words | Not compliant yet | Measured at approximately 217 words. |
| Methodology length 4–6 pages | Requires final pagination check | The current PDF is 16 pages overall; exact methodology-only page count must be checked after final formatting. |
| Step-by-step development process | Compliant | Sections 2.1 and 2.7 describe audit, API work, authentication, screens, and fixes. |
| Tools and reasons for choices | Partially compliant | The technology table lists tools, but the reasons for selecting each tool need more explicit explanation. |
| Iterations, changes, and fixes | Compliant | Authentication race, response envelope, storage, entry point, and icon-bundling fixes are described. |
| Challenges and solutions | Compliant | Section 2.9 gives specific technical challenges and solutions. |
| Rationale for choices | Partially compliant | Rationale is present for Agile and some architecture choices but should be expanded for database, API, mobile framework, and AI decisions. |
| Useful code/design detail | Compliant | API route, response envelope, token handling, models, and service behaviour are described. |
| Visuals in methodology | Partially compliant | Architecture and activity visuals are present; a use-case and class/ER visual are still only requested as placeholders. |
| Product evaluation length 1–2 pages | Not yet confirmed | Chapter 3 contains more than the factual product-evaluation material; it must be paginated and condensed during the correction phase. |
| Factual testing results | Partially compliant | Results are labelled as documented evidence, but some rows still require rerun verification. |
| User testing results | Transparent but incomplete | The report correctly avoids inventing participants and provides a fill-in table. Actual evidence is still required if user testing occurred. |
| Clear labelled visuals | Partially compliant | Captions exist, but Chapter 1–2 numbering is out of sequence and some placeholders remain. |
| No interpretation in product evaluation | Needs review | Some Chapter 3 statements describe scope and limitations; these should be separated from the later reflective discussion. |
| Interpretation and reflection | Compliant in substance | Chapter 4 discusses outcomes, gaps, lessons, and future work in first person. |
| Discussion length 3–5 pages | Requires final pagination check | Content appears substantial, but exact formatted page count is not yet verified. |
| Conclusion length 0.5–1 page | Requires final pagination check | Content is concise, but final page layout must confirm length. |
| Appendices optional and useful | Partially compliant | Appendix topics are useful, but the report should reference each appendix only if the material is actually supplied. |
| References if needed | Partially compliant | References are listed, but access dates/URLs and the exact university guide citation may need to follow the required reference style. |

## Chapter 1 audit

The report's “Project Overview” is clear and technically grounded. It explains
the product, objective, approach, and limitations. The main correction is to
reduce it from approximately 217 words to 150–200 words and compress it into
the guide's requested 2–3 sentence project summary.

The title page is structurally suitable, but it is not submission-ready until
the approved title, student name, ID, supervisor, department, and final date
are supplied. The Chapter 1 hero visual is an existing frontend asset and is
labelled honestly; it should be retained only if the final report needs a
project-context visual.

## Chapter 2 audit

The methodology chapter is the strongest part of the report. It includes the
development approach, requirements, data collection, system requirements,
architecture, tools, implementation iterations, testing approach, and
challenges.

The following corrections are required in the next phase:

1. Replace the “Figure placeholder” sentence for the use-case design with a
   real diagram or explicitly mark it as pending evidence.
2. Add a real class/ER diagram or explicitly mark it as pending evidence.
3. Correct figure order. The current source labels the activity visual as
   Figure 3 and the architecture visual as Figure 2, although the activity
   visual appears first.
4. Ensure every diagram is referred to in the surrounding paragraph.
5. Explain the selection rationale for Rails, PostgreSQL, Expo, TypeScript,
   Axios, React Navigation, Devise, and the AI provider.
6. Confirm whether “manual system checks” were actually executed and add dates
   or move them to planned work.
7. Replace claims based only on old project documentation with current test
   evidence where available.

## Formatting and evidence audit

- The generated PDF opens as a valid A4 PDF and is currently 16 pages.
- The report's Markdown source and PDF are not guaranteed to have accurate
  page-numbered contents because the PDF renderer does not generate a dynamic
  table of contents.
- The current PDF renderer is a lightweight Markdown renderer, not a full
  UNIMTECH typesetting workflow. Font, line spacing, figure anchoring, and
  caption layout require a formatting pass.
- The report intentionally contains evidence placeholders. They should not be
  removed unless the corresponding screenshots, diagrams, test logs, or
  participant records are supplied.
- No claim can guarantee that images bypass AI-detection systems. The audit
  instead checks that visuals are authentic, relevant, labelled, and traceable
  to the project.

## Phase 2 completion checklist

- [x] Compared report structure with the guideline
- [x] Checked title-page fields
- [x] Checked overview content and word count
- [x] Checked methodology requirements
- [x] Checked product-evaluation requirements
- [x] Checked reflection and conclusion requirements
- [x] Checked appendix and reference requirements
- [x] Checked images, captions, and figure references
- [x] Checked current PDF page count and validity
- [x] Recorded gaps without editing the report
- [ ] Correction phase — not started
