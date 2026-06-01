--- STEAMODDED HEADER
--- MOD_NAME: Copy Jokers
--- MOD_ID: CopyJokers
--- MOD_AUTHOR: [BrandonLeho]
--- MOD_DESCRIPTION: Jokers that copy other Jokers

-- Copy joker helpers

local copy_joker_slugs = {
    mirrorjoker = true,
    tailgaterjoker = true,
    appraiserjoker = true,
    uncommongroundjoker = true,
    stagerightjoker = true,

    j_mirrorjoker = true,
    j_tailgaterjoker = true,
    j_appraiserjoker = true,
    j_uncommongroundjoker = true,
    j_stagerightjoker = true,
}

local function normalize_joker_key(key)
    if not key then return nil end

    if string.sub(key, 1, 2) == 'j_' then
        return string.sub(key, 3)
    end

    return key
end

local function get_joker_key(card)
    if card and card.config and card.config.center and card.config.center.key then
        return card.config.center.key
    end

    if card and card.config and card.center and card.config.center.slug then
        return card.config.center.slug
    end

    if card and card.ability and card.ability.name then
        return card.ability.name
    end

    return nil
end

local function is_copy_joker(card)
    local key = get_joker_key(card)
    local normalized_key = normalize_joker_key(key)

    if key and copy_joker_slugs[key] then return true end
    if normalized_key and copy_joker_slugs[normalized_key] then return true end

    if card and card.config and card.config.center and card.config.center.slug then
        local slug = card.config.center.slug
        return copy_joker_slugs[slug] or copy_joker_slugs[normalize_joker_key(slug)] or false
    end

    return false
end

local function is_valid_copy_target(source, target)
    if not source or not target then return false end
    if source == target then return false end
    if target.debuff then return false end
    if is_copy_joker(target) then return false end

    if target.config and target.config.center and target.config.center.blueprint_compat == false then
        return false
    end

    return true
end

local function get_joker_index(card)
    if not G.jokers or not G.jokers.cards then return nil end

    for i = 1, #G.jokers.cards do
        if G.jokers.cards[i] == card then
            return i
        end
    end

    return nil
end

local function get_joker_rarity(card)
    if card and card.config and card.config.center and card.config.center.rarity then
        return card.config.center.rarity
    end

    return nil
end

-- Uses vanilla Blueprint behavior by temporarily presenting the copy joker as Blueprint.
local card_calculate_joker_ref = Card.calculate_joker

local function make_blueprint_order(source, target)
    if not G.jokers or not G.jokers.cards then return nil end

    local old_cards = G.jokers.cards
    local temp_cards = {}

    for i = 1, #old_cards do
        if old_cards[i] ~= source then
            table.insert(temp_cards, old_cards[i])
        end
    end

    -- Blueprint copies the Joker to its right, so place source before target.
    for i = 1, #temp_cards do
        if temp_cards[i] == target then
            table.insert(temp_cards, i, source)
            return old_cards, temp_cards
        end
    end

    return nil
end

local function copy_joker_effect(source, target, context)
    if not is_valid_copy_target(source, target) then return nil end
    if not context then return nil end
    if not card_calculate_joker_ref then return nil end
    if not G.P_CENTERS or not G.P_CENTERS.j_blueprint then return nil end

    -- Avoid runaway copy loops.
    if context.blueprint and context.blueprint > #G.jokers.cards + 1 then
        return nil
    end

    local old_cards, temp_cards = make_blueprint_order(source, target)
    if not old_cards or not temp_cards then return nil end

    local old_center = source.config.center
    local old_ability_name = source.ability.name
    local old_ability_extra = source.ability.extra

    source.config.center = G.P_CENTERS.j_blueprint
    source.ability.name = 'Blueprint'
    source.ability.extra = source.ability.extra or {}

    G.jokers.cards = temp_cards

    local ret = card_calculate_joker_ref(source, context)

    G.jokers.cards = old_cards
    source.config.center = old_center
    source.ability.name = old_ability_name
    source.ability.extra = old_ability_extra

    if ret then
        ret.card = source
        ret.colour = G.C.BLUE
        return ret
    end

    return nil
end

local function is_scoring_copy_context(context)
    if not context then return false end

    -- Main Joker scoring effects, such as Joker, The Duo, The Trio, The Family, etc.
    if context.joker_main then
        return true
    end

    if SMODS.end_calculate_context(context) then
        return true
    end

    -- Card-by-card scoring effects, such as Lusty Joker or Greedy Joker.
    if context.individual and context.cardarea == G.play then
        return true
    end

    -- Held-in-hand scoring effects, such as Baron or Shoot the Moon.
    if context.individual and context.cardarea == G.hand then
        return true
    end

    if context.repetition then
        return true
    end

    return false
end

-- Target selectors

local function target_joker_to_left(card)
    local i = get_joker_index(card)
    if not i then return nil end

    local target = G.jokers.cards[i - 1]
    if is_valid_copy_target(card, target) then
        return target
    end

    return nil
end

local function target_joker_to_right(card)
    local i = get_joker_index(card)
    if not i then return nil end

    local target = G.jokers.cards[i + 1]
    if is_valid_copy_target(card, target) then
        return target
    end

    return nil
end

local function target_rightmost_joker(card)
    if not G.jokers or not G.jokers.cards then return nil end

    for i = #G.jokers.cards, 1, -1 do
        local target = G.jokers.cards[i]
        if is_valid_copy_target(card, target) then
            return target
        end
    end

    return nil
end

local function target_highest_sell_value_joker(card)
    if not G.jokers or not G.jokers.cards then return nil end

    local best_target = nil
    local best_value = -1

    for i = 1, #G.jokers.cards do
        local target = G.jokers.cards[i]

        if is_valid_copy_target(card, target) then
            local value = target.sell_cost or 0

            -- Ties prefer the farther-right Joker.
            if value >= best_value then
                best_target = target
                best_value = value
            end
        end
    end

    return best_target
end

local function target_same_uncommon_rarity_joker(card)
    if not G.jokers or not G.jokers.cards then return nil end

    local i = get_joker_index(card)
    if not i then return nil end

    local uncommon_rarity = 2

    -- Prefer uncommon Jokers to the right, then search left.
    for j = i + 1, #G.jokers.cards do
        local target = G.jokers.cards[j]
        if is_valid_copy_target(card, target) and get_joker_rarity(target) == uncommon_rarity then
            return target
        end
    end

    for j = i - 1, 1, -1 do
        local target = G.jokers.cards[j]
        if is_valid_copy_target(card, target) and get_joker_rarity(target) == uncommon_rarity then
            return target
        end
    end

    return nil
end

local function copy_status_vars(card, target)
    if is_valid_copy_target(card, target) then
        return "Compatible", ""
    else
        return "", "Incompatible"
    end
end

-- Joker definitions

local jokers = {
    mirrorjoker = {
        name = "Mirror Joker",
        text = {
            "Copies the ability of",
            "the {C:attention}Joker to the left{}",
            "{C:inactive}Currently: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 3,
        cost = 10,
        blueprint_compat = false,
        eternal_compat = true,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            return copy_joker_effect(self, target_joker_to_left(self), context)
        end,

        loc_def = function(self)
            local good, bad = copy_status_vars(self, target_joker_to_left(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    tailgaterjoker = {
        name = "Tailgater Joker",
        text = {
            "Copies the ability of",
            "the {C:attention}rightmost Joker{}",
            "{C:inactive}Currently: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 3,
        cost = 10,
        blueprint_compat = false,
        eternal_compat = true,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            return copy_joker_effect(self, target_rightmost_joker(self), context)
        end,

        loc_def = function(self)
            local good, bad = copy_status_vars(self, target_rightmost_joker(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    appraiserjoker = {
        name = "Appraiser",
        text = {
            "Copies the ability of",
            "the Joker with the",
            "{C:money}highest sell value{}",
            "{C:inactive}Currently: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 3,
        cost = 10,
        blueprint_compat = false,
        eternal_compat = true,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            return copy_joker_effect(self, target_highest_sell_value_joker(self), context)
        end,

        loc_def = function(self)
            local good, bad = copy_status_vars(self, target_highest_sell_value_joker(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    uncommongroundjoker = {
        name = "Uncommon Ground",
        text = {
            "Copies the ability of",
            "an {C:green}Uncommon{} Joker",
            "prioritizes Jokers to the {C:attention}right{}",
            "{C:inactive}Currently: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 2,
        cost = 8,
        blueprint_compat = false,
        eternal_compat = true,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            return copy_joker_effect(self, target_same_uncommon_rarity_joker(self), context)
        end,

        loc_def = function(self)
            local good, bad = copy_status_vars(self, target_same_uncommon_rarity_joker(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    stagerightjoker = {
        name = "Stage Right",
        text = {
            "During scoring, copies",
            "the ability of the",
            "{C:attention}Joker to the right{}",
            "{C:inactive}Currently: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 2,
        cost = 7,
        blueprint_compat = false,
        eternal_compat = true,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            if is_scoring_copy_context(context) then
                return copy_joker_effect(self, target_joker_to_right(self), context)
            end
        end,

        loc_def = function(self)
            local good, bad = copy_status_vars(self, target_joker_to_right(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },
}

function SMODS.INIT.CopyJokers()
    init_localization()

    for k, v in pairs(jokers) do
        local joker = SMODS.Joker:new(
            v.name,
            k,
            v.config,
            v.pos,
            { name = v.name, text = v.text },
            v.rarity,
            v.cost,
            v.unlocked,
            v.discovered,
            v.blueprint_compat,
            v.eternal_compat,
            v.effect,
            v.atlas,
            v.soul_pos
        )

        joker:register()

        if not v.atlas then
            SMODS.Sprite:new(
                "j_" .. k,
                SMODS.findModByID("CopyJokers").path,
                "j_" .. k .. ".png",
                71,
                95,
                "asset_atli"
            ):register()
        end

        SMODS.Jokers[joker.slug].calculate = v.calculate
        SMODS.Jokers[joker.slug].loc_def = v.loc_def

        if v.tooltip ~= nil then
            SMODS.Jokers[joker.slug].tooltip = v.tooltip
        end
    end
end
