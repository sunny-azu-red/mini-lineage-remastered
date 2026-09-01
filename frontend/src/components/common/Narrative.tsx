interface NarrativeProps {
    html: string;
    /** Defaults to a `<span>` so this composes inline inside a `<p>`. */
    as?: 'span' | 'div';
}

/**
 * The ONE component that renders server-composed narrative HTML (`<span class="xp">…`). Safe by
 * construction: no player-controlled string is ever interpolated into these templates server-side.
 * Do not widen its use without re-verifying that server-side.
 */
export default function Narrative({ html, as: Tag = 'span' }: NarrativeProps) {
    return <Tag dangerouslySetInnerHTML={{ __html: html }} />;
}
