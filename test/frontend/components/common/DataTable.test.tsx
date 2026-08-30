import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import DataTable, { type Column } from '@/components/common/DataTable';

interface Row {
    id: number;
    name: string;
    level: number;
}

const ROWS: Row[] = [{ id: 1, name: 'Champion', level: 10 }];

describe('DataTable', () => {
    it('applies className to the <td> but not the <th>, matching the old templates where only body cells were colored', () => {
        const columns: Column<Row>[] = [
            { key: 'name', header: 'Name', render: r => r.name },
            { key: 'level', header: 'Level', className: 'gold', render: r => String(r.level) },
        ];
        const { container } = render(<DataTable minWidth={100} columns={columns} rows={ROWS} rowKey={r => r.id} />);

        expect(container.querySelector('td.gold')?.textContent).toBe('10');
        expect(container.querySelector('th.gold')).toBeNull();
    });

    it('applies headerClassName to the <th> for column-wide alignment (e.g. "center")', () => {
        const columns: Column<Row>[] = [
            { key: 'name', header: 'Name', render: r => r.name },
            { key: 'level', header: 'Level', headerClassName: 'center', className: 'center', render: r => String(r.level) },
        ];
        const { container } = render(<DataTable minWidth={100} columns={columns} rows={ROWS} rowKey={r => r.id} />);

        expect(container.querySelector('th.center')?.textContent).toBe('Level');
        expect(container.querySelector('td.center')?.textContent).toBe('10');
    });

    it('leaves className/headerClassName off the <td>/<th> when not specified', () => {
        const columns: Column<Row>[] = [{ key: 'name', header: 'Name', render: r => r.name }];
        const { container } = render(<DataTable minWidth={100} columns={columns} rows={ROWS} rowKey={r => r.id} />);

        const td = container.querySelector('td') as HTMLElement;
        const th = container.querySelector('th') as HTMLElement;
        expect(td.className).toBe('');
        expect(th.className).toBe('');
    });
});
