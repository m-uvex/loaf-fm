import type { ReactNode } from "react";

function inline(text: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const re =
    /(\*\*[^*\n]+\*\*|~~[^~\n]+~~|\*[^*\n]+\*|_[^_\n]+_|`[^`]+`|\[[^\]]+\]\([^)\s]+\)|https?:\/\/[^\s<)]+[^\s<).,;:!?])/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let k = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) nodes.push(text.slice(last, m.index));
    const tok = m[0];
    if (tok.startsWith("**")) {
      nodes.push(<strong key={k++}>{inline(tok.slice(2, -2))}</strong>);
    } else if (tok.startsWith("~~")) {
      nodes.push(<del key={k++}>{inline(tok.slice(2, -2))}</del>);
    } else if (
      (tok.startsWith("*") && tok.endsWith("*")) ||
      (tok.startsWith("_") && tok.endsWith("_"))
    ) {
      nodes.push(<em key={k++}>{inline(tok.slice(1, -1))}</em>);
    } else if (tok.startsWith("`")) {
      nodes.push(<code key={k++}>{tok.slice(1, -1)}</code>);
    } else if (tok.startsWith("[")) {
      const mm = tok.match(/^\[([^\]]+)\]\(([^)]+)\)$/);
      if (mm) {
        nodes.push(
          <a key={k++} href={mm[2]} target="_blank" rel="noreferrer">
            {inline(mm[1])}
          </a>,
        );
      } else {
        nodes.push(tok);
      }
    } else if (/^https?:\/\//.test(tok)) {
      nodes.push(
        <a key={k++} href={tok} target="_blank" rel="noreferrer">
          {tok}
        </a>,
      );
    } else {
      nodes.push(tok);
    }
    last = m.index + tok.length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}

const HTML_TAG =
  /<\/?(?:img|p|div|br|hr|picture|source|video|audio|iframe|details|summary|table|thead|tbody|tfoot|tr|td|th|h[1-6]|ul|ol|li|a|code|pre|span|strong|em|sub|sup|kbd|s|b|i|u|center|blockquote|input)(?:\s[^>]*)?>/gi;

function splitTableRow(line: string): string[] {
  let s = line.trim();
  if (s.startsWith("|")) s = s.slice(1);
  if (s.endsWith("|")) s = s.slice(0, -1);
  return s.split("|").map((c) => c.trim());
}
function isTableSep(line: string): boolean {
  return /^\s*\|?(\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$/.test(line);
}
function isTableRow(line: string): boolean {
  return /^\s*\|.*\|\s*$/.test(line) || (line.includes("|") && !/^\s*$/.test(line));
}

export function Markdown({ source }: { source: string }) {
  const nodes: ReactNode[] = [];
  const lines = source.replace(/!\[[^\]]*\]\([^)]+\)/g, "").split(/\r?\n/);
  let i = 0;
  let ul: string[] = [];
  let ol: string[] = [];
  let quote: string[] = [];
  let fence: string[] | null = null;
  let key = 0;

  const flushUl = () => {
    if (!ul.length) return;
    nodes.push(
      <ul key={key++}>
        {ul.map((item, j) => {
          const task = item.match(/^\[( |x|X)\]\s+(.*)$/);
          if (task) {
            const checked = task[1].toLowerCase() === "x";
            return (
              <li key={j} className="md-task">
                <input type="checkbox" checked={checked} readOnly disabled />
                <span>{inline(task[2])}</span>
              </li>
            );
          }
          return <li key={j}>{inline(item)}</li>;
        })}
      </ul>,
    );
    ul = [];
  };
  const flushOl = () => {
    if (!ol.length) return;
    nodes.push(
      <ol key={key++}>
        {ol.map((item, j) => (
          <li key={j}>{inline(item)}</li>
        ))}
      </ol>,
    );
    ol = [];
  };
  const flushQuote = () => {
    if (!quote.length) return;
    nodes.push(
      <blockquote key={key++}>
        {quote.map((q, j) => (
          <p key={j}>{inline(q)}</p>
        ))}
      </blockquote>,
    );
    quote = [];
  };
  const flushBlocks = () => {
    flushUl();
    flushOl();
    flushQuote();
  };

  while (i < lines.length) {
    const raw = lines[i];
    const line = raw.replace(/\s+$/, "");

    if (fence !== null) {
      if (/^```/.test(line)) {
        nodes.push(
          <pre key={key++}>
            <code>{fence.join("\n")}</code>
          </pre>,
        );
        fence = null;
      } else {
        fence.push(line);
      }
      i++;
      continue;
    }

    if (/^```/.test(line)) {
      flushBlocks();
      fence = [];
      i++;
      continue;
    }

    const clean = line.replace(HTML_TAG, "");

    if (/^\s*$/.test(clean)) {
      flushBlocks();
      i++;
      continue;
    }

    // Table: header | sep | rows
    if (
      isTableRow(clean) &&
      i + 1 < lines.length &&
      isTableSep(lines[i + 1].replace(HTML_TAG, ""))
    ) {
      flushBlocks();
      const head = splitTableRow(clean);
      i += 2; // skip header + separator
      const rows: string[][] = [];
      while (i < lines.length) {
        const rc = lines[i].replace(/\s+$/, "").replace(HTML_TAG, "");
        if (!isTableRow(rc) || /^\s*$/.test(rc)) break;
        rows.push(splitTableRow(rc));
        i++;
      }
      nodes.push(
        <div className="md-table-wrap" key={key++}>
          <table>
            <thead>
              <tr>
                {head.map((c, j) => (
                  <th key={j}>{inline(c)}</th>
                ))}
              </tr>
            </thead>
            {rows.length > 0 && (
              <tbody>
                {rows.map((r, ri) => (
                  <tr key={ri}>
                    {head.map((_, j) => (
                      <td key={j}>{inline(r[j] ?? "")}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            )}
          </table>
        </div>,
      );
      continue;
    }

    const h = clean.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      flushBlocks();
      nodes.push(
        h[1].length <= 2 ? (
          <h3 key={key++}>{inline(h[2])}</h3>
        ) : (
          <h4 key={key++}>{inline(h[2])}</h4>
        ),
      );
      i++;
      continue;
    }

    if (/^\s*---+\s*$/.test(clean) || /^\s*\*\*\*+\s*$/.test(clean)) {
      flushBlocks();
      nodes.push(<hr key={key++} />);
      i++;
      continue;
    }

    const bq = clean.match(/^\s*>\s?(.*)$/);
    if (bq) {
      flushUl();
      flushOl();
      quote.push(bq[1]);
      i++;
      continue;
    }
    if (quote.length) flushQuote();

    const uli = clean.match(/^\s*[-*+]\s+(.*)$/);
    if (uli) {
      flushOl();
      ul.push(uli[1]);
      i++;
      continue;
    }
    if (ul.length) flushUl();

    const oli = clean.match(/^\s*\d+\.\s+(.*)$/);
    if (oli) {
      flushUl();
      ol.push(oli[1]);
      i++;
      continue;
    }
    if (ol.length) flushOl();

    nodes.push(<p key={key++}>{inline(clean)}</p>);
    i++;
  }

  if (fence !== null) {
    nodes.push(
      <pre key={key++}>
        <code>{fence.join("\n")}</code>
      </pre>,
    );
  }
  flushBlocks();
  return <div className="md">{nodes}</div>;
}
