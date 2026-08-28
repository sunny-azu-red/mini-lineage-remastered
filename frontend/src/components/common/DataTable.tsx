import type { ReactNode } from 'react';

export interface Column<R> {
    key: string;
    header: string;
    headerTitle?: string;
    /**
     * Applied to the `<th>` — only ever used for alignment (e.g. 'center'), matching the old EJS
     * templates' `<th class="center">`. None of the old tables ever colored a header, only body
     * cells — so this is deliberately separate from `className` below rather than one prop shared
     * by both, which would otherwise also tint headers for color-utility columns like 'gold'.
     */
    headerClassName?: string;
    /**
     * Applied to the `<td>` itself (e.g. 'center', 'gold', 'muted') — for styling that's constant
     * for every row in this column, exactly like the old EJS templates' `<td class="gold">`/
     * `<td class="center">`. A column whose styling instead VARIES per row (e.g. a crit% that's
     * only colored when > 0, otherwise a muted "-") should keep wrapping its own value in a
     * `<span className="...">` from `render` instead — same as those old templates did.
     */
    className?: string;
    render: (row: R) => ReactNode;
}

interface DataTableProps<R> {
    minWidth: number;
    columns: Column<R>[];
    rows: R[];
    rowKey: (row: R) => string | number;
}

/**
 * Generic port of the `.table-container > table.data-table` shape shared by
 * weapons-shop.ejs/armors-shop.ejs/inn.ejs — same `min-width` inline style and `thead`/`tbody`
 * structure, same `<th title="...">` tooltip pattern for stat columns, just parameterized over
 * columns/rows so one component covers all three (and, later, highscores.ejs).
 */
export default function DataTable<R>({ minWidth, columns, rows, rowKey }: DataTableProps<R>) {
    return (
        <div className="table-container">
            <table className="data-table" style={{ minWidth }}>
                <thead>
                    <tr>
                        {columns.map(col => (
                            <th key={col.key} title={col.headerTitle} className={col.headerClassName}>
                                {col.header}
                            </th>
                        ))}
                    </tr>
                </thead>
                <tbody>
                    {rows.map(row => (
                        <tr key={rowKey(row)}>
                            {columns.map(col => (
                                <td key={col.key} className={col.className}>{col.render(row)}</td>
                            ))}
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}
