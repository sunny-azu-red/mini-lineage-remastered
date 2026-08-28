import type { ReactNode } from 'react';

export interface Column<R> {
    key: string;
    header: string;
    headerTitle?: string;
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
                            <th key={col.key} title={col.headerTitle}>
                                {col.header}
                            </th>
                        ))}
                    </tr>
                </thead>
                <tbody>
                    {rows.map(row => (
                        <tr key={rowKey(row)}>
                            {columns.map(col => (
                                <td key={col.key}>{col.render(row)}</td>
                            ))}
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}
