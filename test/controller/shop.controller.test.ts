import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getWeaponsShop, postWeaponsShop, getArmorsShop, postArmorsShop, getInn, postInn } from '@/controller/shop.controller';
import * as playerService from '@/service/player.service';
import * as shopView from '@/view/shop.view';
import { ItemType } from '@/interface';

vi.mock('@/service/player.service', () => ({
    purchaseItem: vi.fn(),
}));

vi.mock('@/view/shop.view', () => ({
    renderWeaponsShopView: vi.fn().mockReturnValue('weapons-shop-view'),
    renderArmorsShopView: vi.fn().mockReturnValue('armors-shop-view'),
    renderInnView: vi.fn().mockReturnValue('inn-view'),
}));

vi.mock('@/middleware/session.middleware', () => ({
    saveAndRedirect: vi.fn().mockImplementation((req, res, next, url) => res.redirect(url)),
}));

describe('shopController', () => {
    let req: any;
    let res: any;
    let next: any;

    beforeEach(() => {
        vi.clearAllMocks();
        req = { body: {} };
        res = {
            locals: { player: {} },
            send: vi.fn(),
            redirect: vi.fn(),
        };
        next = vi.fn();
    });

    describe('getHandlers', () => {
        it('should render weapons shop', () => {
            getWeaponsShop(req, res);
            expect(shopView.renderWeaponsShopView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('weapons-shop-view');
        });

        it('should render armors shop', () => {
            getArmorsShop(req, res);
            expect(shopView.renderArmorsShopView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('armors-shop-view');
        });

        it('should render inn', () => {
            getInn(req, res);
            expect(shopView.renderInnView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('inn-view');
        });
    });

    describe('postHandlers', () => {
        it('should handle weapon purchase', () => {
            req.body = { select_weapon: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue({ success: true, text: 'Bought', item: {} as any });
            postWeaponsShop(req, res, next);
            expect(playerService.purchaseItem).toHaveBeenCalledWith(res.locals.player, ItemType.Weapon, 1);
            expect(res.redirect).toHaveBeenCalledWith('/shop/weapons');
        });

        it('should handle weapon purchase', () => {
            req.body = { select_weapon: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue({ success: true, text: 'Bought', item: {} as any });
            postWeaponsShop(req, res, next);
            expect(playerService.purchaseItem).toHaveBeenCalledWith(res.locals.player, ItemType.Weapon, 1);
            expect(res.redirect).toHaveBeenCalledWith('/shop/weapons');
        });

        it('should handle weapon purchase with no result (invalid item)', () => {
            req.body = { select_weapon: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue(null);
            postWeaponsShop(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/shop/weapons');
        });

        it('should handle armor purchase', () => {
            req.body = { select_armor: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue({ success: true, text: 'Bought', item: {} as any });
            postArmorsShop(req, res, next);
            expect(playerService.purchaseItem).toHaveBeenCalledWith(res.locals.player, ItemType.Armor, 1);
            expect(res.redirect).toHaveBeenCalledWith('/shop/armors');
        });

        it('should handle armor purchase with no result', () => {
            req.body = { select_armor: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue(null);
            postArmorsShop(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/shop/armors');
        });

        it('should handle food purchase', () => {
            req.body = { select_food: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue({ success: true, text: 'Bought', item: {} as any });
            postInn(req, res, next);
            expect(playerService.purchaseItem).toHaveBeenCalledWith(res.locals.player, ItemType.Food, 1);
            expect(res.redirect).toHaveBeenCalledWith('/inn');
        });

        it('should handle food purchase with no result', () => {
            req.body = { select_food: '1' };
            vi.mocked(playerService.purchaseItem).mockReturnValue(null);
            postInn(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/inn');
        });

        it('should redirect home if selection is missing', () => {
            postWeaponsShop(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/');

            vi.clearAllMocks();
            postArmorsShop(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/');

            vi.clearAllMocks();
            postInn(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should call next with error if validation fails', () => {
            req.body = { select_weapon: 'invalid' };
            postWeaponsShop(req, res, next);
            expect(next).toHaveBeenCalledWith(expect.any(Error));

            vi.clearAllMocks();
            req.body = { select_armor: 'invalid' };
            postArmorsShop(req, res, next);
            expect(next).toHaveBeenCalledWith(expect.any(Error));

            vi.clearAllMocks();
            req.body = { select_food: 'invalid' };
            postInn(req, res, next);
            expect(next).toHaveBeenCalledWith(expect.any(Error));
        });
    });
});
