import type { ReactNode } from 'react';

export interface Column<R> {
    key: string;
    header: string;
    headerTitle?: string;
    /** Applied to the `<th>` — alignment only; headers are never colour-tinted. */
    headerClassName?: string;
    /**
     * Applied to the `<td>`, for styling constant across every row (e.g. 'gold', 'center').
     * A column whose styling VARIES per row should wrap its value in a span from `render`.
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

/** The shared `.table-container > table.data-table` shape used by the shops and highscores. */
export default function DataTable<R>({ minWidth, columns, rows, rowKey }: DataTableProps<R>) {
    return (
        <div className="table-container">
            <table className="data-table" style={{ minWidth }}>
                <thead>
                    <tr>
                        {columns.map(col => (
                            <th key={col.key} title={col.headerTitle} className={col.headerClassName}>{col.header}</th>
                        ))}
                    </tr>
                </thead>
                <tbody>
                    {rows.map(row => (
                        <tr key={rowKey(row)}>
                            {columns.map(col => <td key={col.key} className={col.className}>{col.render(row)}</td>)}
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}
