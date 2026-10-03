-- Tests for visual and audio feedback: effects, sound, and their wiring

require("tests.spec_helper")

local data = require("src.models.data")
local effects = require("src.systems.effects")
local sound = require("src.systems.sound")
local combat_system = require("src.systems.combat_system")
local game_controller = require("src.controllers.game_controller")
local Walker = require("src.entities.walker")

describe("Feedback", function()
    describe("effects", function()
        local group

        before_each(function()
            group = display.newGroup()
            effects.initialize(group)
        end)

        after_each(function()
            effects.cleanup()
        end)

        it("draws a rounded damage number and a spark at the hit point", function()
            effects.damageNumber(100, 200, 6.6)
            effects.hitSpark(100, 200)

            assert.are.equal(2, group.numChildren)
            assert.are.equal("7", group[1].text)
            assert.are.equal(1, effects.getActiveNumberCount())
        end)

        it("caps damage numbers on screen", function()
            for _ = 1, 60 do
                effects.damageNumber(100, 200, 1)
            end
            assert.are.equal(40, effects.getActiveNumberCount())
        end)

        it("shakes the target and settles back when the shake ends", function()
            effects.screenShake(5, 0.2)
            assert.is_true(effects.isShaking())

            effects.update(0.1)
            assert.is_true(math.abs(group.x) <= 5 and math.abs(group.y) <= 5)

            effects.update(0.2)
            assert.is_false(effects.isShaking())
            assert.are.equal(0, group.x)
            assert.are.equal(0, group.y)
        end)

        it("keeps the stronger and longer of two shakes", function()
            effects.screenShake(8, 0.1)
            effects.screenShake(2, 0.5)
            effects.update(0.3)
            assert.is_true(effects.isShaking())
        end)

        it("does nothing before initialize", function()
            effects.cleanup()
            assert.has_no.errors(function()
                effects.damageNumber(0, 0, 5)
                effects.hitSpark(0, 0)
                effects.update(0.1)
            end)
        end)
    end)

    describe("sound", function()
        local originalPathForFile
        local originalPlay
        local played

        before_each(function()
            data.startSandbox()
            originalPathForFile = system.pathForFile
            originalPlay = audio.play
            played = {}
            audio.play = function(handle) table.insert(played, handle) end
        end)

        after_each(function()
            system.pathForFile = originalPathForFile
            audio.play = originalPlay
            sound.cleanup()
            data.stopSandbox(false)
        end)

        it("plays a loaded sound effect", function()
            sound.initialize()
            assert.is_true(sound.isLoaded("hit"))
            assert.is_true(sound.play("hit"))
            assert.are.equal(1, #played)
        end)

        it("skips sounds whose files are missing", function()
            system.pathForFile = function(path, dir)
                if path:find("^assets/audio/") then return nil end
                return originalPathForFile(path, dir)
            end
            sound.initialize()

            assert.is_false(sound.isLoaded("hit"))
            assert.is_false(sound.play("hit"))
            assert.is_false(sound.playMusic())
        end)

        it("does not play the same sound twice in quick succession", function()
            sound.initialize()
            assert.is_true(sound.play("hit"))
            assert.is_false(sound.play("hit"))
        end)

        it("respects the sound and music settings", function()
            data.set("settings.soundOn", false)
            data.set("settings.musicOn", false)
            sound.initialize()

            assert.is_false(sound.play("hit"))
            assert.is_false(sound.playMusic())
        end)

        it("starts music once", function()
            sound.initialize()
            assert.is_true(sound.playMusic())
            assert.is_false(sound.playMusic())
            sound.stopMusic()
            assert.is_true(sound.playMusic())
        end)
    end)

    describe("wiring", function()
        local restoreEffects
        local restoreSound
        local calls

        before_each(function()
            restoreEffects = snapshotModule(effects)
            restoreSound = snapshotModule(sound)
            calls = {}
            effects.damageNumber = function(x, y, amount, killed)
                table.insert(calls, { "number", amount, killed })
            end
            effects.hitSpark = function() table.insert(calls, { "spark" }) end
            effects.screenShake = function(intensity) table.insert(calls, { "shake", intensity }) end
            sound.play = function(name) table.insert(calls, { "sound", name }) end
        end)

        after_each(function()
            restoreEffects()
            restoreSound()
            combat_system.onEnemyDamaged = nil
        end)

        local function has(kind, value)
            for _, call in ipairs(calls) do
                if call[1] == kind and (value == nil or call[2] == value) then
                    return true
                end
            end
            return false
        end

        it("reports hits and kills from applyDamage", function()
            combat_system.onEnemyDamaged = game_controller.onEnemyDamaged
            local walker = Walker:new(nil)
            walker:activate(100, 100, 100)

            combat_system.applyDamage(walker, 5)
            assert.is_true(has("number", 5))
            assert.is_true(has("sound", "hit"))

            combat_system.applyDamage(walker, 50)
            assert.is_true(has("sound", "enemy_death"))
        end)

        it("does not report damage to the wall or a dead enemy", function()
            local reported = 0
            combat_system.onEnemyDamaged = function() reported = reported + 1 end
            local wall = { health = 100, takeDamage = function(self, amount) self.health = self.health - amount end }
            local dead = Walker:new(nil)
            dead:activate(100, 100, 100)
            dead:deactivate()

            combat_system.applyDamage(wall, 10)
            combat_system.applyDamage(dead, 10)

            assert.are.equal(0, reported)
        end)

        it("shakes and plays the boss sound when a boss arrives", function()
            game_controller.onBossSpawned({ isBoss = true })
            assert.is_true(has("sound", "boss"))
            assert.is_true(has("shake"))
        end)
    end)
end)
