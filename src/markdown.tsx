import type { ReactNode } from "react";

function inline(text: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)\s]+\))/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let k = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) nodes.push(text.slice(last, m.index));
    const tok = m[0];
    if (tok.startsWith("**")) nodes.push(<strong key={k++}>{tok.slice(2, -2)}</strong>);
    else if (tok.startsWith("`")) nodes.push(<code key={k++}>{tok.slice(1, -1)}</code>);
    else {
      const mm = tok.match(/^\[([^\]]+)\]\(([^)]+)\)$/);
      if (mm) nodes.push(<a key={k++} href={mm[2]} target="_blank" rel="noreferrer">{mm[1]}</a>);
      else nodes.push(tok);
    }
    last = m.index + tok.length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}

export function Markdown({ source }: { source: string }) {
  const nodes: ReactNode[] = [];
  const lines = source.replace(/!\[[^\]]*\]\([^)]+\)/g, "").split(/\r?\n/);
  let list: string[] = [];
  let fence: string[] | null = null;
  const flushList = () => {
    if (list.length) {
      nodes.push(
        <ul key={nodes.length}>
          {list.map((li, i) => (
            <li key={i}>{inline(li)}</li>
          ))}
        </ul>,
      );
      list = [];
    }
  };
  for (const raw of lines) {
    const line = raw.replace(/\s+$/, "");
    if (fence !== null) {
      if (/^```/.test(line)) {
        nodes.push(
          <pre key={nodes.length}>
            <code>{fence.join("\n")}</code>
          </pre>,
        );
        fence = null;
      } else {
        fence.push(line);
      }
      continue;
    }
    if (/^```/.test(line)) {
      flushList();
      fence = [];
      continue;
    }
    if (/^\s*$/.test(line)) {
      flushList();
      continue;
    }
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      flushList();
      nodes.push(
        h[1].length <= 2 ? (
          <h3 key={nodes.length}>{inline(h[2])}</h3>
        ) : (
          <h4 key={nodes.length}>{inline(h[2])}</h4>
        ),
      );
      continue;
    }
    if (/^\s*---+\s*$/.test(line)) {
      flushList();
      nodes.push(<hr key={nodes.length} />);
      continue;
    }
    const li = line.match(/^\s*[-*]\s+(.*)$/);
    if (li) {
      list.push(li[1]);
      continue;
    }
    flushList();
    nodes.push(<p key={nodes.length}>{inline(line)}</p>);
  }
  if (fence !== null) {
    nodes.push(
      <pre key={nodes.length}>
        <code>{fence.join("\n")}</code>
      </pre>,
    );
  }
  flushList();
  return <div className="md">{nodes}</div>;
}
