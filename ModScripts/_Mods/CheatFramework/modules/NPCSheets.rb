FrameworkModule = {
  name:       "NPC Sheets",
  key:        :npc_sheets,
  menu:       :NPC,
  order:      95,
  depends_on: [:invedit]
}

#--------------------------------------------------------------------------
# Character Discovery
#--------------------------------------------------------------------------
# Characters with a full actor ($game_NPC_actors), read from the same
# Data/Effects/_Sys_Actor JSON the game uses to build them.
module MenuFramework
  module NPCSheets
    extend self

    # States kept out of the companion state editor.
    EXCLUDED_STATES = /Booba/
    EXCLUDED_TAGS = /trait/

    def characters
      @characters ||= begin
        data = $data_ActorJson
        data ||= FileGetter.load_source_actor_data("Data/Effects/_Sys_Actor/*.json") if FileGetter.respond_to?(:load_source_actor_data)
        # Builds without upgraded NPCs have no actor data, so no sheets.
        data = {} unless data.is_a?(Hash)
        data.values.each_with_object([]) do |json, list|
          next unless json.is_a?(Hash)
          src = json["source_actor_data"]
          (src.is_a?(Array) ? src : [src]).each do |entry|
            next unless entry.is_a?(Hash) && entry["name"] && entry["actor_id"]
            list << { name: entry["name"], actor_id: entry["actor_id"], event_id: entry["event_id"], key: entry["name"].gsub(/\W/, "") }
          end
        end
      end
    end

    def actor(name)
      $game_NPC_actors && $game_NPC_actors[name]
    end

    # Filters by state name and by the state's type_tag.
    def state_allowed?(state_name)
      state = $data_StateName[state_name]
      state_name !~ EXCLUDED_STATES && !(state && state.type_tag =~ EXCLUDED_TAGS)
    end

    # Save-local infinite stat toggles, keyed by actor_id.
    def infinite?(actor_id, stat)
      $story_stats && $story_stats["CF_npc_infinite_#{stat}_#{actor_id}"] == 1
    end

    def toggle_infinite(actor_id, stat)
      $story_stats["CF_npc_infinite_#{stat}_#{actor_id}"] = infinite?(actor_id, stat) ? 0 : 1
    end

    # Raises a stat (health/sta/sat) to its max.
    def fill(npc, stat)
      max = npc.battle_stat.get_stat(stat, ActorStat::MAX_STAT)
      npc.send("#{stat}=", max) if npc.send(stat) < max
    end

    def heal(npc)
      ["health", "sta", "sat"].each { |stat| fill(npc, stat) }
    end

    def apply_infinite_stats
      characters.each do |char|
        npc = actor(char[:name])
        next unless npc
        fill(npc, "health") if infinite?(char[:actor_id], :health)
        fill(npc, "sta")    if infinite?(char[:actor_id], :stamina)
        fill(npc, "sat")    if infinite?(char[:actor_id], :food)
      end
    end

    # Save-local bonuses, added on top of the values recalculate_stats rebuilds.
    # weak/sexy are rebuilt in refresh, like Lona; the rest in recalculate_stats.
    REFRESH_BONUS_STATS = ["weak", "sexy"]
    RECALC_BONUS_STATS  = ["atk", "def", "wisdom"]

    # Ground stats: the bonus goes onto max and check_single_stat re-syncs current.
    def apply_refresh_bonuses(npc)
      stats = npc.actStat
      REFRESH_BONUS_STATS.each do |name|
        b = bonus(npc, name)
        next if b == 0
        value = [stats.get_stat(name) + b, stats.get_stat(name, ActorStat::MIN_STAT)].max
        stats.set_stat(name, value, ActorStat::MAX_STAT)
        stats.check_single_stat(name)
      end
    end

    def apply_recalc_bonuses(npc)
      RECALC_BONUS_STATS.each do |name|
        b = bonus(npc, name)
        npc.send("#{name}=", npc.send(name) + b) if b != 0
      end
    end

    def bonus(npc, stat)
      ($story_stats && $story_stats["CF_bonus_#{npc.actor_id}_#{stat}"]) || 0
    end

    # Zeroes the bonus first so the actor's own value is the base, then stores the difference.
    def set_bonus(npc, stat, target)
      key = "CF_bonus_#{npc.actor_id}_#{stat}"
      $story_stats[key] = 0
      npc.refresh
      npc.recalculate_stats
      $story_stats[key] = (target - npc.send(stat)).round(3)
      npc.refresh
      npc.recalculate_stats
    end

    # Value without the bonus: current value minus the saved bonus.
    def base(npc, stat)
      npc.send(stat) - bonus(npc, stat)
    end

    # "(+B) A": the saved bonus (plus any change being dialed in); plain value when zero.
    def bonus_display(npc, stat, value)
      b = (value - base(npc, stat)).round
      b == 0 ? value.round.to_s : "(%+d) %d" % [b, value.round]
    end

    # Morality is morality_plus on sheet NPCs; its true max persists, so gear buffs stay on top.
    def set_morality(npc, value)
      npc.refresh
      stats = npc.actStat
      buff = stats.get_stat("morality_plus", ActorStat::MAX_STAT) - stats.get_stat("morality_plus", ActorStat::MAX_TRUE)
      stats.set_stat("morality_plus", value - buff, ActorStat::MAX_TRUE)
      npc.refresh
    end

    # Morality from her NPC data plus current gear: the value with no edit.
    def morality_base(npc, event_id)
      data = $data_npcs && $data_npcs[event_id]
      return nil unless data && data.morality
      stats = npc.actStat
      data.morality + stats.get_stat("morality_plus", ActorStat::MAX_STAT) - stats.get_stat("morality_plus", ActorStat::MAX_TRUE)
    end

    # "(+B) A" where B is the edit's offset from her NPC data value.
    def morality_display(npc, event_id, value)
      base = morality_base(npc, event_id)
      b = base ? (value - base).round : 0
      b == 0 ? value.round.to_s : "(%+d) %d" % [b, value.round]
    end

    # Dirt's true max pinned to 0, same as Lona's Disable Dirt.
    def dirt_disabled?(npc)
      npc.actStat.get_stat("dirt", ActorStat::MAX_TRUE) == 0
    end

    def toggle_dirt(npc)
      npc.actStat.set_stat("dirt", dirt_disabled?(npc) ? 255 : 0, ActorStat::MAX_TRUE)
      npc.refresh
    end
  end
end

class Game_NPC_Actor
  alias_method :cf_npcsheets_refresh, :refresh
  def refresh
    cf_npcsheets_refresh
    MenuFramework::NPCSheets.apply_refresh_bonuses(self)
  end

  alias_method :cf_npcsheets_recalculate_stats, :recalculate_stats
  def recalculate_stats
    cf_npcsheets_recalculate_stats
    MenuFramework::NPCSheets.apply_recalc_bonuses(self)
  end
end

#--------------------------------------------------------------------------
# State Editor Window
#--------------------------------------------------------------------------
# InvEdit's status window, pointed at one character.
MenuFramework::NPCSheets.characters.each do |char|
  Object.const_set("Window_CheatMenuNPCStatus#{char[:key]}", Class.new(Window_CheatMenuStatus) do
    define_method(:status_actor) { MenuFramework::NPCSheets.actor(char[:name]) }
    define_method(:status_allowed?) { |state_name| super(state_name) && MenuFramework::NPCSheets.state_allowed?(state_name) }
  end)
end

#--------------------------------------------------------------------------
# Menu Commands
#--------------------------------------------------------------------------
module MenuFramework
  module SUBMENU
    MenuFramework::NPCSheets.characters.each_with_index do |char, i|
      name  = char[:name]
      id    = char[:actor_id]
      group = "NPC_#{char[:key].upcase}".to_sym
      stats = "NPC_#{char[:key].upcase}_PRIMARY".to_sym
      ref   = "MenuFramework::NPCSheets.actor(#{name.inspect})"
      npc   = -> { MenuFramework::NPCSheets.actor(name) }

      register_command(
        group:  :NPC,
        type:   :scene,
        key:    "Sheet #{name}",
        label:  -> { name },
        menu1:  -> { name },
        name:   "CheatMenuNPCSheet#{char[:key]}",
        dict:   group,
        order:  10 + i
      )
      register_command(
        group:  group,
        type:   :scene,
        key:    "Primary Stats",
        label:  "modules/character:commands/primary",
        menu1:  -> { name },
        name:   "CheatMenuNPCPrimary#{char[:key]}",
        dict:   stats,
        order:  10
      )

      #------------------------------------------------------------------------
      # Vitals
      #------------------------------------------------------------------------
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Health",
        label:  "modules/character:commands/primary/health",
        state:  "#{ref}.health.to_i",
        enable: -> { !MenuFramework::NPCSheets.infinite?(id, :health) },
        min:    -100,
        max:    999,
        default: -> { npc.call.battle_stat.get_stat("health", ActorStat::MAX_STAT).to_i },
        action: ->(v) { npc.call.health = v },
        order:  10
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Stamina",
        label:  "modules/character:commands/primary/stamina",
        state:  "#{ref}.sta.to_i",
        enable: -> { !MenuFramework::NPCSheets.infinite?(id, :stamina) },
        min:    -100,
        max:    200,
        default: -> { npc.call.battle_stat.get_stat("sta", ActorStat::MAX_STAT).to_i },
        action: ->(v) { npc.call.sta = v },
        order:  20
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Food",
        label:  "modules/character:commands/primary/food",
        state:  "#{ref}.sat.to_i",
        enable: -> { !MenuFramework::NPCSheets.infinite?(id, :food) },
        min:    0,
        max:    200,
        default: -> { npc.call.battle_stat.get_stat("sat", ActorStat::MAX_STAT).to_i },
        action: ->(v) { npc.call.sat = v },
        order:  30
      )

      #------------------------------------------------------------------------
      # Combat Stats
      #------------------------------------------------------------------------
      register_command(
        group:   stats,
        type:    :edit_num,
        key:     "Attack",
        label:   "modules/character:commands/primary/attack",
        state:   "#{ref}.atk.round",
        help1:   "modules/character:command_help/primary/bonus",
        help2:   "modules/character:command_help/primary/bonus2",
        min:     0,
        max:     -> { MenuFramework::NPCSheets.base(npc.call, "atk").round + 250 },
        default: -> { MenuFramework::NPCSheets.base(npc.call, "atk").round },
        display: ->(v) { MenuFramework::NPCSheets.bonus_display(npc.call, "atk", v) },
        action:  ->(v) { MenuFramework::NPCSheets.set_bonus(npc.call, "atk", v) },
        order:   40
      )
      register_command(
        group:   stats,
        type:    :edit_num,
        key:     "Wisdom",
        label:   "modules/character:commands/primary/wisdom",
        state:   "#{ref}.wisdom.round",
        help1:   "modules/character:command_help/primary/bonus",
        help2:   "modules/character:command_help/primary/bonus2",
        min:     0,
        max:     -> { MenuFramework::NPCSheets.base(npc.call, "wisdom").round + 250 },
        default: -> { MenuFramework::NPCSheets.base(npc.call, "wisdom").round },
        display: ->(v) { MenuFramework::NPCSheets.bonus_display(npc.call, "wisdom", v) },
        action:  ->(v) { MenuFramework::NPCSheets.set_bonus(npc.call, "wisdom", v) },
        order:   60
      )
      register_command(
        group:   stats,
        type:    :edit_num,
        key:     "Defense",
        label:   "modules/character:commands/primary/defense",
        state:   "#{ref}.def.round",
        help1:   "modules/character:command_help/primary/bonus",
        help2:   "modules/character:command_help/primary/bonus2",
        min:     0,
        max:     -> { MenuFramework::NPCSheets.base(npc.call, "def").round + 250 },
        default: -> { MenuFramework::NPCSheets.base(npc.call, "def").round },
        display: ->(v) { MenuFramework::NPCSheets.bonus_display(npc.call, "def", v) },
        action:  ->(v) { MenuFramework::NPCSheets.set_bonus(npc.call, "def", v) },
        order:   50
      )

      #------------------------------------------------------------------------
      # Other Stats
      #------------------------------------------------------------------------
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Mood",
        label:  "modules/character:commands/primary/mood",
        state:  "#{ref}.mood.to_i",
        min:    -100,
        max:    100,
        action: ->(v) { npc.call.mood = v },
        order:  70
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Dirt",
        label:  "modules/character:commands/appearance/dirt",
        state:  "#{ref}.dirt.to_i",
        enable: -> { !MenuFramework::NPCSheets.dirt_disabled?(npc.call) },
        min:    0,
        max:    255,
        action: ->(v) { npc.call.dirt = v },
        order:  80
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Arousal",
        label:  "modules/character:commands/primary/arousal",
        state:  "#{ref}.arousal.to_i",
        min:    0,
        max:    5000,
        action: ->(v) { npc.call.arousal = v },
        order:  90
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Morality",
        label:  "modules/character:commands/primary/morality",
        state:   "#{ref}.morality.round",
        help1:   "modules/character:command_help/moral",
        min:     0,
        max:     200,
        default: -> { (MenuFramework::NPCSheets.morality_base(npc.call, char[:event_id]) || 50).round },
        display: ->(v) { MenuFramework::NPCSheets.morality_display(npc.call, char[:event_id], v) },
        action:  ->(v) { MenuFramework::NPCSheets.set_morality(npc.call, v) },
        order:   100
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Sexy",
        label:  "modules/character:commands/primary/sexy",
        state:  "#{ref}.sexy.to_i",
        help1:  "modules/character:command_help/primary/bonus",
        help2:  "modules/character:command_help/primary/bonus2",
        min:    -> { MenuFramework::NPCSheets.base(npc.call, "sexy").round - 1500 },
        max:    -> { MenuFramework::NPCSheets.base(npc.call, "sexy").round + 1500 },
        default: -> { MenuFramework::NPCSheets.base(npc.call, "sexy").round },
        display: ->(v) { MenuFramework::NPCSheets.bonus_display(npc.call, "sexy", v) },
        action:  ->(v) { MenuFramework::NPCSheets.set_bonus(npc.call, "sexy", v) },
        order:  110
      )
      register_command(
        group:  stats,
        type:   :edit_num,
        key:    "Weak",
        label:  "modules/character:commands/primary/weak",
        state:  "#{ref}.weak.to_i",
        help1:  "modules/character:command_help/primary/bonus",
        help2:  "modules/character:command_help/primary/bonus2",
        min:    -> { MenuFramework::NPCSheets.base(npc.call, "weak").round - 1500 },
        max:    -> { MenuFramework::NPCSheets.base(npc.call, "weak").round + 1500},
        default: -> { MenuFramework::NPCSheets.base(npc.call, "weak").round },
        display: ->(v) { MenuFramework::NPCSheets.bonus_display(npc.call, "weak", v) },
        action:  ->(v) { MenuFramework::NPCSheets.set_bonus(npc.call, "weak", v) },
        order:  120
      )



      #------------------------------------------------------------------------
      # Infinite Stats
      #------------------------------------------------------------------------
      register_command(
        group:  group,
        type:   :toggle,
        key:    "Infinite Health",
        label:  "modules/mainstatus:toggle/health",
        state:  "MenuFramework::NPCSheets.infinite?(#{id.inspect}, :health)",
        action: -> { MenuFramework::NPCSheets.toggle_infinite(id, :health) },
        order:  80
      )
      register_command(
        group:  group,
        type:   :toggle,
        key:    "Infinite Stamina",
        label:  "modules/mainstatus:toggle/stamina",
        state:  "MenuFramework::NPCSheets.infinite?(#{id.inspect}, :stamina)",
        action: -> { MenuFramework::NPCSheets.toggle_infinite(id, :stamina) },
        order:  90
      )
      register_command(
        group:  group,
        type:   :toggle,
        key:    "Infinite Food",
        label:  "modules/mainstatus:toggle/food",
        state:  "MenuFramework::NPCSheets.infinite?(#{id.inspect}, :food)",
        action: -> { MenuFramework::NPCSheets.toggle_infinite(id, :food) },
        order:  100
      )
      register_command(
        group:  group,
        type:   :toggle,
        key:    "Disable Dirt",
        label:  "modules/character:toggle/dirt",
        help1:  "modules/character:command_help/dirt",
        state:  "MenuFramework::NPCSheets.dirt_disabled?(#{ref})",
        action: -> { MenuFramework::NPCSheets.toggle_dirt(npc.call) },
        order:  105
      )

      #------------------------------------------------------------------------
      # Actions
      #------------------------------------------------------------------------
      register_command(
        group:  group,
        type:   :action,
        key:    "Heal",
        label:  "modules/mainstatus:misc/heal",
        action: -> { MenuFramework::NPCSheets.heal(npc.call) },
        order:  110
      )
      register_command(
        group:  group,
        type:   :action,
        key:    "Heal Wound",
        label:  "modules/mainstatus:misc/heal_wound",
        help1:  "modules/mainstatus:command_help/heal_wound",
        action: -> { npc.call.heal_wound },
        order:  120
      )
      register_command(
        group:  group,
        type:   :scene,
        key:    "State Editor",
        label:  "modules/invedit:commands/status",
        name:   "CheatMenuNPCStatus#{char[:key]}",
        dict:   :NONE,
        order:  130
      )
    end
  end
end

#--------------------------------------------------------------------------
# Hotkey Hook
#--------------------------------------------------------------------------
class CheatFramework
  alias_method :hotkey_trigger_NPCSHEETS, :hotkey_trigger
  def hotkey_trigger
    hotkey_trigger_NPCSHEETS
    MenuFramework::NPCSheets.apply_infinite_stats if FrameworkUtils.ingame?
  end
end
