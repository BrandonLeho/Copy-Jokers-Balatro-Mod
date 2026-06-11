--- STEAMODDED HEADER
--- MOD_NAME: Copy Jokers
--- MOD_ID: CopyJokers
--- MOD_AUTHOR: [Brandon]
--- MOD_DESCRIPTION: Jokers that copy other Jokers

-- Copy joker helpers

-- These are excluded as targets to avoid recursive copy/duplicate chains.
local copy_joker_slugs = {
    mirrorjoker = true,
    tailgaterjoker = true,
    appraiserjoker = true,
    uncommongroundjoker = true,
    stagerightjoker = true,
    receiptprinterjoker = true,
    counterfeitjoker = true,
    clonestampjoker = true,
    echonegativejoker = true,
    doubleornothingjoker = true,

    j_mirrorjoker = true,
    j_tailgaterjoker = true,
    j_appraiserjoker = true,
    j_uncommongroundjoker = true,
    j_stagerightjoker = true,
    j_receiptprinterjoker = true,
    j_counterfeitjoker = true,
    j_clonestampjoker = true,
    j_echonegativejoker = true,
    j_doubleornothingjoker = true,
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

local function is_temporary_copy(card)
    return card and card.ability and card.ability.copyjokers_temporary
end

local function is_valid_copy_target(source, target)
    if not source or not target then return false end
    if source == target then return false end
    if target.debuff then return false end
    if is_copy_joker(target) then return false end
    if is_temporary_copy(target) then return false end

    if target.config and target.config.center and target.config.center.blueprint_compat == false then
        return false
    end

    return true
end

local function is_valid_duplicate_target(source, target)
    if not source or not target then return false end
    if source == target then return false end
    if target.debuff then return false end
    if is_copy_joker(target) then return false end
    if is_temporary_copy(target) then return false end

    -- Duplicating the actual Joker should not care about Blueprint compatibility.
    return true
end

local function is_destructible_joker(card)
    return card and card.ability and not card.ability.eternal
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

    if context.joker_main then return true end
    if SMODS.end_calculate_context(context) then return true end
    if context.individual and context.cardarea == G.play then return true end
    if context.individual and context.cardarea == G.hand then return true end
    if context.repetition then return true end

    return false
end

-- Duplicate joker helpers

local function has_joker_room(negative)
    if negative then return true end
    if not G.jokers or not G.jokers.cards or not G.jokers.config then return false end
    return #G.jokers.cards + (G.GAME.joker_buffer or 0) < G.jokers.config.card_limit
end

local function apply_negative_edition(card)
    if not card then return end

    if card.set_edition then
        card:set_edition({ negative = true }, true)
    else
        card.edition = card.edition or {}
        card.edition.negative = true
    end

    if card.set_cost then
        card:set_cost()
    end
end

local function destroy_joker_card(card)
    if not card then return end

    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.05,
        func = function()
            if card and card.area then
                play_sound('tarot1')
                card.T.r = -0.2
                card:juice_up(0.3, 0.4)
                card.states.drag.is = true

                if card.children and card.children.center then
                    card.children.center.pinch.x = true
                end

                if G.jokers then
                    G.jokers:remove_card(card)
                end

                card:remove()
            end
            return true
        end
    }))
end

local function create_joker_duplicate(target, negative, temporary)
    if not target then return nil end
    if not negative and not has_joker_room(false) then return nil end

    G.GAME.joker_buffer = (G.GAME.joker_buffer or 0) + 1

    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.1,
        func = function()
            local new_card = copy_card(target, nil, nil, nil, negative)

            if negative then
                apply_negative_edition(new_card)
            end

            if temporary then
                new_card.ability.copyjokers_temporary = true
            end

            new_card:add_to_deck()
            G.jokers:emplace(new_card)

            G.GAME.joker_buffer = math.max(0, (G.GAME.joker_buffer or 1) - 1)
            return true
        end
    }))

    return true
end

local function destroy_source_then_duplicate(source, target, negative, temporary)
    if not source or not target then return nil end

    destroy_joker_card(source)

    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.2,
        func = function()
            create_joker_duplicate(target, negative, temporary)
            return true
        end
    }))

    return true
end

local function cleanup_temporary_duplicates()
    if not G.jokers or not G.jokers.cards then return end

    for i = #G.jokers.cards, 1, -1 do
        local card = G.jokers.cards[i]
        if is_temporary_copy(card) then
            destroy_joker_card(card)
        end
    end
end

local function popup(card, message, colour)
    if card_eval_status_text then
        card_eval_status_text(card, 'extra', nil, nil, nil, { message = message, colour = colour })
    end
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

local function duplicate_target_joker_to_left(card)
    local i = get_joker_index(card)
    if not i then return nil end

    local target = G.jokers.cards[i - 1]
    if is_valid_duplicate_target(card, target) then
        return target
    end

    return nil
end

local function duplicate_target_joker_to_right(card)
    local i = get_joker_index(card)
    if not i then return nil end

    local target = G.jokers.cards[i + 1]
    if is_valid_duplicate_target(card, target) then
        return target
    end

    return nil
end

local function duplicate_target_joker_to_right_destructible(card)
    local target = duplicate_target_joker_to_right(card)

    if target and is_destructible_joker(target) then
        return target
    end

    return nil
end

local function duplicate_target_rightmost_joker(card)
    if not G.jokers or not G.jokers.cards then return nil end

    for i = #G.jokers.cards, 1, -1 do
        local target = G.jokers.cards[i]
        if is_valid_duplicate_target(card, target) then
            return target
        end
    end

    return nil
end

local function duplicate_target_highest_sell_value_joker(card)
    if not G.jokers or not G.jokers.cards then return nil end

    local best_target = nil
    local best_value = -1

    for i = 1, #G.jokers.cards do
        local target = G.jokers.cards[i]

        if is_valid_duplicate_target(card, target) then
            local value = target.sell_cost or 0

            if value >= best_value then
                best_target = target
                best_value = value
            end
        end
    end

    return best_target
end

local function copy_status_vars(card, target)
    if is_valid_copy_target(card, target) then
        return "Compatible", ""
    else
        return "", "Incompatible"
    end
end

local function duplicate_status_vars(card, target)
    if is_valid_duplicate_target(card, target) then
        return "Ready", ""
    else
        return "", "No Target"
    end
end

local function destructible_duplicate_status_vars(card, target)
    if is_valid_duplicate_target(card, target) and is_destructible_joker(target) then
        return "Ready", ""
    else
        return "", "No Target"
    end
end

local function is_safe_blind_select_context(self, context)
    return context.setting_blind and not self.getting_sliced and not context.blueprint
end

local function is_safe_end_round_context(context)
    return context.end_of_round and not context.individual and not context.repetition and not context.blueprint
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
            "{C:inactive}(prioritizes far right, searches left){}",
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
            "{C:inactive}(ties prioritize rightmost){}",
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
            "{C:inactive}(prioritizes right, then left){}",
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

    receiptprinterjoker = {
        name = "Receipt Printer",
        text = {
            "When blind is selected,",
            "create a {C:dark_edition}Negative{} temporary copy",
            "of the {C:attention}newest valid Joker{}",
            "{C:inactive}(prioritizes far right, searches left){}",
            "{C:inactive}Target: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 3,
        cost = 9,
        blueprint_compat = false,
        eternal_compat = true,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            if is_safe_blind_select_context(self, context) then
                local target = duplicate_target_rightmost_joker(self)
                if target then
                    create_joker_duplicate(target, true, true)
                    return { message = "Printed!", colour = G.C.BLUE, card = self }
                end
            end

            if is_safe_end_round_context(context) then
                cleanup_temporary_duplicates()
            end
        end,

        loc_def = function(self)
            local good, bad = duplicate_status_vars(self, duplicate_target_rightmost_joker(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    counterfeitjoker = {
        name = "Counterfeit Joker",
        text = {
            "When blind is selected,",
            "if you have {C:money}$0{} or less, copy",
            "the Joker with the {C:money}highest sell value{}",
            "then destroy this Joker",
            "{C:inactive}(ties prioritize rightmost){}",
            "{C:inactive}Target: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 2,
        cost = 5,
        blueprint_compat = false,
        eternal_compat = false,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            if is_safe_blind_select_context(self, context) and G.GAME.dollars <= 0 then
                local target = duplicate_target_highest_sell_value_joker(self)
                if target then
                    popup(self, "Counterfeit!", G.C.MONEY)
                    destroy_source_then_duplicate(self, target, false, false)
                    return nil
                end
            end
        end,

        loc_def = function(self)
            local good, bad = duplicate_status_vars(self, duplicate_target_highest_sell_value_joker(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    clonestampjoker = {
        name = "Clone Stamp",
        text = {
            "When a {C:attention}Joker{} is sold,",
            "copy the Joker to the {C:attention}left{},",
            "then destroy this Joker",
            "{C:inactive}Target: {C:green}#3#{C:red}#4#{}",
        },
        config = { extra = { mult = 0, x_mult = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 3,
        cost = 7,
        blueprint_compat = false,
        eternal_compat = false,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            if context.selling_card and not context.blueprint then
                local sold = nil

                if type(context.selling_card) == 'table' then
                    sold = context.selling_card
                elseif type(context.card) == 'table' then
                    sold = context.card
                end

                if not sold then return nil end

                local target = duplicate_target_joker_to_left(self)

                if sold ~= self
                and sold.ability
                and sold.ability.set == 'Joker'
                and target
                and target ~= sold then
                    popup(self, "Stamped!", G.C.BLUE)
                    destroy_source_then_duplicate(self, target, false, false)
                    return nil
                end
            end
        end,

        loc_def = function(self)
            local good, bad = duplicate_status_vars(self, duplicate_target_joker_to_left(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, good, bad }
        end,
    },

    echonegativejoker = {
        name = "Echo",
        text = {
            "After {C:attention}#3#{} rounds, create a",
            "{C:dark_edition}Negative{} copy of the",
            "Joker to the {C:attention}right{},",
            "then destroy this Joker",
            "{C:inactive}(currently #4#/#3#){}",
            "{C:inactive}Target: {C:green}#5#{C:red}#6#{}",
        },
        config = { extra = { mult = 0, x_mult = 0, rounds_needed = 4, rounds = 0 } },
        pos = { x = 0, y = 0 },
        rarity = 3,
        cost = 10,
        blueprint_compat = false,
        eternal_compat = false,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            if is_safe_end_round_context(context) then
                self.ability.extra.rounds = (self.ability.extra.rounds or 0) + 1

                if self.ability.extra.rounds >= self.ability.extra.rounds_needed then
                    local target = duplicate_target_joker_to_right(self)
                    if target then
                        popup(self, "Echo!", G.C.PURPLE)
                        destroy_source_then_duplicate(self, target, true, false)
                    end
                else
                    return { message = self.ability.extra.rounds .. "/" .. self.ability.extra.rounds_needed, colour = G.C.FILTER, card = self }
                end
            end
        end,

        loc_def = function(self)
            local good, bad = duplicate_status_vars(self, duplicate_target_joker_to_right(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, self.ability.extra.rounds_needed, self.ability.extra.rounds, good, bad }
        end,
    },

    doubleornothingjoker = {
        name = "Double or Nothing",
        text = {
            "When blind is selected,",
            "{C:green}#4# in #3#{} chance to copy",
            "the Joker to the {C:attention}right{}",
            "and destroy this Joker",
            "{C:red}Fail:{} destroy both Jokers",
            "{C:inactive}Target: {C:green}#5#{C:red}#6#{}",
        },
        config = { extra = { mult = 0, x_mult = 0, odds = 2, normal = 1 } },
        pos = { x = 0, y = 0 },
        rarity = 2,
        cost = 6,
        blueprint_compat = false,
        eternal_compat = false,
        unlocked = true,
        discovered = true,
        effect = nil,
        atlas = nil,
        soul_pos = nil,

        calculate = function(self, context)
            if is_safe_blind_select_context(self, context) then
                local target = duplicate_target_joker_to_right_destructible(self)

                if target then
                    if pseudorandom('doubleornothingjoker') < G.GAME.probabilities.normal / self.ability.extra.odds then
                        popup(self, "Success!", G.C.GREEN)
                        destroy_source_then_duplicate(self, target, false, false)
                    else
                        popup(self, "Bust!", G.C.RED)
                        destroy_joker_card(target)
                        destroy_joker_card(self)
                    end
                end
            end
        end,

        loc_def = function(self)
            local good, bad = destructible_duplicate_status_vars(self, duplicate_target_joker_to_right_destructible(self))
            return { self.ability.extra.mult, self.ability.extra.x_mult, self.ability.extra.odds, G.GAME and G.GAME.probabilities.normal or 1, good, bad }
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
