FrameworkModule = {
  name:       "Clothing Utils",
  key:        :clothing_utils,
}

#--------------------------------------------------------------------------
# Menu Commands
#--------------------------------------------------------------------------
module MenuFramework
  module SUBMENU
    register_command(
      group:  :FIXES,
      type:   :edit_list,
      key:    "Prevent Discard",
      label:  "modules/others:commands/discard",
      help1:  "modules/others:command_help/discard1",
      help2:  "menu:command_help/fixcommand2",
      state:  "$cheat_prevent_clothing_discard",
      # Inline 3-state list instead of reusing Fixes.rb's FIX_TOGGLE_LIST.
      list:   [
                { key: -1, label: "[#{$framework.txt("menu:cheat_toggle/disable")}]" },
                { key:  0, label: "[#{$framework.txt("menu:cheat_toggle/off")}]" },
                { key:  1, label: "[#{$framework.txt("menu:cheat_toggle/on")}]" },
              ],
      gdef:   0,
      restart: -1,
      order:  50
    )
    register_command(
      group:  :MISC,
      type:   :action,
      key:    "Remove Clothes",
      label:  "modules/others:commands/stripredress",
      help1:  "modules/others:command_help/stripredress1",
      help2:  "modules/others:command_help/stripredress2",
      hotkey: {key: "F3"},
      action: -> { FrameworkUtils.toggle_clothing },
      order:  60
    )
    register_command(
      group:  :MISC,
      type:   :action,
      key:    "Force Remove Clothes",
      label:  "modules/others:commands/forceunequip",
      help1:  "modules/others:command_help/forceunequip1",
      hotkey: {key: "Shift+F3"},
      action: -> { FrameworkUtils.unequipall(true) },
      order:  70
    )
  end
end

module FrameworkUtils
  # Per-save record of the stripped clothing, as { slot => item name }.
  CLOTHING_STATE_KEY = "CF_stripped_clothing"

  # Re-equips the saved clothing if there is any, otherwise strips and saves it.
  def self.toggle_clothing
    return unless self.ingame?
    actor = $game_player.actor
    saved = $story_stats[CLOTHING_STATE_KEY]
    if saved.is_a?(Hash)
      saved.each do |slot, name|
        next unless name.is_a?(String) && actor.equip_change_ok?(slot) && actor.equips[slot].nil?
        actor.change_equip(slot, name)
      end
      $story_stats[CLOTHING_STATE_KEY] = 0
      SndLib.sound_equip_armor
    else
      before = actor.equips
      unequipall(false)
      after = actor.equips
      removed = {}
      before.each_with_index { |item, slot| removed[slot] = item.item_name if item && after[slot].nil? }
      $story_stats[CLOTHING_STATE_KEY] = removed unless removed.empty?
    end
  end

  def self.unequipall(force)
    if self.ingame?
      actor = $game_player.actor
      actor.equip_slots.size.times do |i|
        item = actor.equips[i]
        next if item && item.type_tag == "Hair"
        bondage = item && item.type_tag == "Bondage"
        actor.change_equip(i, nil) if actor.equip_change_ok?(i) || (force && bondage)
        SndLib.sound_equip_armor
      end
    end
  end
end

#--------------------------------------------------------------------------
# Prevent Discard Patch
#--------------------------------------------------------------------------
if $cheat_prevent_clothing_discard >= 0
  if defined?(Game_Actor) && Game_Actor.method_defined?(:remove_equip_on_hit)
    class Game_Actor
      alias_method :cf_prevent_discard_remove_equip_on_hit, :remove_equip_on_hit
      def remove_equip_on_hit(slot_key=self.remove_equip_slot_picker, summon=true, sound_play=true)
        @cf_keep_discarded = $cheat_prevent_clothing_discard == 1
        cf_prevent_discard_remove_equip_on_hit(slot_key, summon, sound_play)
      ensure
        @cf_keep_discarded = false
      end

      # Hit-removal keeps the item in the inventory instead of deleting it.
      if method_defined?(:remove_equip_drop)
        alias_method :cf_prevent_discard_remove_equip_drop, :remove_equip_drop
        def remove_equip_drop(slot_key, summon=true, sound_play=true)
          return cf_prevent_discard_remove_equip_drop(slot_key, summon, sound_play) unless @cf_keep_discarded
          slot_id = $data_system.equip_type_name[slot_key]
          return if equips[slot_id].nil?
          weapon = equips[slot_id].is_a?(RPG::Weapon)
          change_equip(slot_id, nil)
          return unless map_token
          update_state_frames
          map_token.update
          return unless sound_play
          if weapon
            SndLib.sound_combat_sword_hit_sword(map_token.report_distance_to_vol_close, 65 + rand(10))
          else
            SndLib.sound_DressTear(map_token.report_distance_to_vol_close, 75 + rand(10))
          end
        end
      end
    end
  elsif defined?(GIM_CHCG) && GIM_CHCG.method_defined?(:combat_remove_random_equip_exec)
    module GIM_CHCG
      alias_method :cf_prevent_discard_combat_remove_random_equip_exec, :combat_remove_random_equip_exec
      def combat_remove_random_equip_exec(tar_name,eqp_target=combat_hit_get_removable_slots,summon=true)
        unless $cheat_prevent_clothing_discard == 1
          return cf_prevent_discard_combat_remove_random_equip_exec(tar_name,eqp_target,summon)
        end
        eqp_target = $data_system.equip_type_name[eqp_target] if eqp_target.is_a?(String)
        $game_player.actor.change_equip(eqp_target, nil)
        weaponSlots = $data_system.weapon_slots
        tarType = weaponSlots.include?(eqp_target) ? "Weapon" : "Armor"
        #$game_party.drop_tgt_item_and_summon(tarType,tar_name,1,summon)
        if weaponSlots.include?(eqp_target) && summon
          SndLib.sound_combat_sword_hit_sword(vol=80,effect=65+rand(10))
        else
          SndLib.sound_DressTear(vol=80,effect=75+rand(10))
        end
        $game_player.actor.update_state_frames
        $game_player.update
      end
    end
  end
end
