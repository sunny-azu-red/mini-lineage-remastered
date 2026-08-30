interface NarrativeProps {
    html: string;
    /** Defaults to a `<span>` so this composes inline inside a `<p>`. */
    as?: 'span' | 'div';
}

/**
 * The ONE component that renders server-composed narrative HTML (`<span class="xp">…`).
 *
 * SAFE BY CONSTRUCTION: no player-controlled string (name, item names, …) is ever interpolated
 * into these templates server-side — player data is always sent as a separate plain field and
 * rendered as normal React children. Do not widen this without re-verifying that server-side.
 */
export default function Narrative({ html, as: Tag = 'span' }: NarrativeProps) {
    return <Tag dangerouslySetInnerHTML={{ __html: html }} />;
}
