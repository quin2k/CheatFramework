FrameworkModule = {
  name:       "Primary Stats",
  key:        :primary,
  menu:       :PRIMARY,
  order:      90,
  depends_on: []
}

module MenuFramework
  module SUBMENU
    #--------------------------------------------------------------------------
    # Character Editing Menu
    #--------------------------------------------------------------------------
    register_command(
      group:  :LONA,
      type:   :scene,
      key:    :edit_primary,
      label:  "modules/character:commands/primary",
      menu1:  "menu:window_help/character1",
      name:   "CheatMenuPrimary",
      dict:   :PRIMARY,
      order:  10
    )

    #--------------------------------------------------------------------------
    # Primary Stats
    #--------------------------------------------------------------------------
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Health",
      label:  "modules/character:commands/primary/health",
      state:  "$game_player.actor.health.to_i",
      enable: -> {!$cheat_infinite_health},
      min:    -100,
      max:    999,
      action: ->(v) { $game_player.actor.health = v },
      order:  10
      )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Stamina",
      label:  "modules/character:commands/primary/stamina",
      enable: -> {!$cheat_infinite_stamina},
      state:  "$game_player.actor.sta.to_i",
      min:    -100,
      max:    200,
      action: ->(v) { $game_player.actor.sta = v },
      order:  20
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Food",
      label:  "modules/character:commands/primary/food",
      enable: -> {!$cheat_infinite_food},
      state:  "$game_player.actor.sat",
      min:    0,
      max:    200,
      action: ->(v) { $game_player.actor.sat = v },
      order:  30
    )
      register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Mood",
      label:  "modules/character:commands/primary/mood",
      state:  "$game_player.actor.mood",
      min:    -100,
      max:    100,
      action: ->(v) { $game_player.actor.mood = v },
      order:  40
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Arousal",
      label:  "modules/character:commands/primary/arousal",
      state:  "$game_player.actor.arousal",
      min:    0,
      max:    5000,
      action: ->(v) { $game_player.actor.arousal = v },
      order:  50
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Morality",
      label:  "modules/character:commands/primary/morality",
      state:  "$game_player.actor.morality",
      help1:  "modules/character:command_help/moral",
      min:    -> {$game_player.actor.morality_plus - 200},
      max:    -> {100 + $game_player.actor.morality_plus - 200},
      action: ->(v) { 
        $game_player.actor.morality_lona = v - $game_player.actor.morality_plus + 200
        $game_player.actor.recalculate_stats
        },
      order:  60
    )

    #--------------------------------------------------------------------------
    # Stat Bonuses
    #--------------------------------------------------------------------------
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Weak",
      label:  "modules/character:commands/primary/weak",
      state:  "$game_player.actor.weak.round",
      help1:  "modules/character:command_help/primary/bonus",
      help2:  "modules/character:command_help/primary/bonus2",
      min:    0,
      max:    1500,
      display: ->(v) { FrameworkUtils.bonus_display(:weak, v) },
      action: ->(v) { FrameworkUtils.set_stat_bonus(:weak, v) },
      order:  70
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Sexy",
      label:  "modules/character:commands/primary/sexy",
      state:  "$game_player.actor.sexy.round",
      help1:  "modules/character:command_help/primary/bonus",
      help2:  "modules/character:command_help/primary/bonus2",
      min:    0,
      max:    1500,
      display: ->(v) { FrameworkUtils.bonus_display(:sexy, v) },
      action: ->(v) { FrameworkUtils.set_stat_bonus(:sexy, v) },
      order:  80
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Attack",
      label:  "modules/character:commands/primary/attack",
      state:  "$game_player.actor.atk.round",
      help1:  "modules/character:command_help/primary/bonus",
      help2:  "modules/character:command_help/primary/bonus2",
      min:    0,
      max:    250,
      display: ->(v) { FrameworkUtils.bonus_display(:atk, v) },
      action: ->(v) { FrameworkUtils.set_stat_bonus(:atk, v) },
      order:  90
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Defense",
      label:  "modules/character:commands/primary/defense",
      state:  "$game_player.actor.def.round",
      help1:  "modules/character:command_help/primary/bonus",
      help2:  "modules/character:command_help/primary/bonus2",
      min:    0,
      max:    250,
      display: ->(v) { FrameworkUtils.bonus_display(:def, v) },
      action: ->(v) { FrameworkUtils.set_stat_bonus(:def, v) },
      order:  100
    )
    register_command(
      group:  :PRIMARY,
      type:   :edit_num,
      key:    "Will",
      label:  "modules/character:commands/primary/will",
      state:  "$game_player.actor.will.round",
      help1:  "modules/character:command_help/primary/will",
      help2:  "modules/character:command_help/primary/bonus2",
      min:    100,
      max:    5000,
      display: ->(v) { FrameworkUtils.bonus_display(:will, v) },
      action: ->(v) { FrameworkUtils.set_stat_bonus(:will, v) },
      order:  110
    )
  end
end

#--------------------------------------------------------------------------
# Stat Bonus Logic
#--------------------------------------------------------------------------
module FrameworkUtils
  # weak/sexy/will are rebuilt from scratch by Game_Actor#refresh; atk/def by #recalculate_stats.
  REFRESH_BONUS_STATS = ["weak", "sexy", "will"]
  RECALC_BONUS_STATS  = ["atk", "def"]

  # Zeroes the bonus first so the actor's own value is the base.
  def self.set_stat_bonus(stat, target)
    actor = $game_player.actor
    $story_stats["CF_bonus_#{stat}"] = 0
    actor.refresh
    $story_stats["CF_bonus_#{stat}"] = (target - actor.send(stat)).round(3)
    actor.refresh
  end

  # Pre-bonus value of each stat as of the last refresh.
  def self.stat_bases
    @stat_bases ||= {}
  end

  # Ground stats keep current synced to max, so the bonus goes onto max and check_single_stat re-syncs.
  def self.apply_refresh_bonuses(actor)
    stats = actor.actStat
    REFRESH_BONUS_STATS.each do |name|
      stat_bases[name] = stats.get_stat(name)
      bonus = stat_bonus(name)
      next if bonus == 0
      value = [stats.get_stat(name) + bonus, stats.get_stat(name, ActorStat::MIN_STAT)].max
      stats.set_stat(name, value, ActorStat::MAX_STAT)
      stats.check_single_stat(name)
    end
  end

  def self.apply_recalc_bonuses(actor)
    RECALC_BONUS_STATS.each do |name|
      stat_bases[name] = actor.send(name)
      bonus = stat_bonus(name)
      actor.send("#{name}=", actor.send(name) + bonus) if bonus != 0
    end
  end

  # "(+B) A": the bonus in effect after the stat's floor; plain value when zero.
  def self.bonus_display(stat, value)
    base = stat_bases[stat.to_s] || ($game_player.actor.send(stat) - stat_bonus(stat))
    bonus = (value - base).round
    bonus == 0 ? value.round.to_s : "(%+d) %d" % [bonus, value.round]
  end
end

class Game_Actor
  alias_method :cf_stat_bonus_refresh, :refresh
  def refresh
    cf_stat_bonus_refresh
    FrameworkUtils.apply_refresh_bonuses(self) if FrameworkUtils.player_actor?(self)
  end

  alias_method :cf_stat_bonus_recalculate_stats, :recalculate_stats
  def recalculate_stats
    cf_stat_bonus_recalculate_stats
    FrameworkUtils.apply_recalc_bonuses(self) if FrameworkUtils.player_actor?(self)
  end
end
