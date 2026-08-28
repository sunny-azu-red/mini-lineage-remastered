interface NarrativeProps {
    html: string;
    /** Defaults to a `<span>` so this composes inline inside a `<p>` (battle narrative lines). */
    as?: 'span' | 'div';
}

/**
 * Plan decision A12 ("Narrative HTML"): battle/statistics/race narrative strings keep their
 * server-embedded HTML (`<span class="xp">...</span>`, etc.) and render through this ONE
 * component. Safe by construction — no player-controlled string (name, item names, ...) is ever
 * interpolated into these templates server-side (see narrative.service.ts / narratives.constant.ts);
 * player-supplied data is always sent as a separate plain field and rendered as normal React
 * children elsewhere. Do not widen this invariant without re-verifying it server-side.
 */
export default function Narrative({ html, as = 'span' }: NarrativeProps) {
    const Tag = as;
    return <Tag dangerouslySetInnerHTML={{ __html: html }} />;
}
