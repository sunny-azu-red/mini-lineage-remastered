import { Request, Response, NextFunction } from 'express';
import { ItemType } from '@/interface';
import { makePurchaseFlash } from '@/util/game.util';
import { renderWeaponsShopView, renderArmorsShopView, renderInnView } from '@/view/shop.view';
import { purchaseItem } from '@/service/player.service';
import { ShopWeaponSchema, ShopArmorSchema, ShopFoodSchema } from '@/schema/shop.schema';
import { saveAndRedirect } from '@/middleware/session.middleware';

export const getWeaponsShop = (req: Request, res: Response) => {
    res.send(renderWeaponsShopView(res.locals.player, res.locals.flash));
};

export const postWeaponsShop = (req: Request, res: Response, next: NextFunction) => {
    if (!req.body.select_weapon)
        return res.redirect('/');

    const parsed = ShopWeaponSchema.safeParse(req.body);
    if (!parsed.success)
        return next(new Error('Invalid weapon selection'));

    const player = res.locals.player;
    const result = purchaseItem(player, ItemType.Weapon, parsed.data.select_weapon);
    if (result)
        player.flash = makePurchaseFlash(result, 'buy');

    saveAndRedirect(req, res, next, '/shop/weapons');
};

export const getArmorsShop = (req: Request, res: Response) => {
    res.send(renderArmorsShopView(res.locals.player, res.locals.flash));
};

export const postArmorsShop = (req: Request, res: Response, next: NextFunction) => {
    if (!req.body.select_armor)
        return res.redirect('/');

    const parsed = ShopArmorSchema.safeParse(req.body);
    if (!parsed.success)
        return next(new Error('Invalid armor selection'));

    const player = res.locals.player;
    const result = purchaseItem(player, ItemType.Armor, parsed.data.select_armor);
    if (result)
        player.flash = makePurchaseFlash(result, 'buy');

    saveAndRedirect(req, res, next, '/shop/armors');
};

export const getInn = (req: Request, res: Response) => {
    res.send(renderInnView(res.locals.player, res.locals.flash));
};

export const postInn = (req: Request, res: Response, next: NextFunction) => {
    if (!req.body.select_food)
        return res.redirect('/');

    const parsed = ShopFoodSchema.safeParse(req.body);
    if (!parsed.success)
        return next(new Error('Invalid food selection'));

    const player = res.locals.player;
    const result = purchaseItem(player, ItemType.Food, parsed.data.select_food);
    if (result)
        player.flash = makePurchaseFlash(result, 'eat');

    saveAndRedirect(req, res, next, '/inn');
};
