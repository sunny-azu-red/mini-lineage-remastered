import { describe, it, expect } from 'vitest';
import { readTemplate, render } from '@/view/base.view';
import { requestContext } from '@/context/request.context';

describe('base.view', () => {
    it('reads template files from disk', () => {
        const tpl = readTemplate('simple.ejs');
        expect(tpl.filename).toBe('simple.ejs');
        expect(tpl.content).toBeDefined();
        expect(typeof tpl.content).toBe('string');
        expect(tpl.content.length).toBeGreaterThan(0);
    });

    it('renders template with custom locals', () => {
        const tpl = { content: '<h1><%= title %></h1>', filename: 'test.ejs' };
        const html = render(tpl, { title: 'Hello World' });
        expect(html).toBe('<h1>Hello World</h1>');
    });

    it('injects cspNonce from requestContext when active', () => {
        const tpl = { content: '<script nonce="<%= cspNonce %>"></script>', filename: 'test.ejs' };
        let html = '';

        requestContext.run({ cspNonce: 'custom-nonce-abc' }, () => {
            html = render(tpl);
        });

        expect(html).toBe('<script nonce="custom-nonce-abc"></script>');
    });

    it('defaults cspNonce to empty string when no requestContext is active', () => {
        const tpl = { content: '<script nonce="<%= cspNonce %>"></script>', filename: 'test.ejs' };
        const html = render(tpl);
        expect(html).toBe('<script nonce=""></script>');
    });
});
