require("tests.spec_helper")
local ArcaneBolt = require("src.entities.abilities.arcane_bolt")

describe("ArcaneBolt Ability", function()
    local ability

    before_each(function()
        ability = ArcaneBolt:new()
    end)

    after_each(function()
        ability = nil
    end)

    describe("initialization", function()
        it("should initialize with correct id", function()
            assert.is.equal("arcane_bolt", ability.id)
        end)

        it("should initialize with correct name", function()
            assert.is.equal("Arcane Bolt", ability.name)
        end)

        it("should initialize with 1.0 second cooldown", function()
            assert.is.equal(1.0, ability.cooldown)
        end)

        it("should initialize with lastActivation at 0", function()
            assert.is.equal(0, ability.lastActivation)
        end)

        it("should initialize with 10 base damage", function()
            assert.is.equal(10, ability.damage)
        end)

        it("should initialize with 400 pixels per second projectile speed", function()
            assert.is.equal(400, ability.projectileSpeed)
        end)

        it("should initialize at tier 1", function()
            assert.is.equal(1, ability.tier)
        end)

        it("should initialize with 0 pierce count", function()
            assert.is.equal(0, ability.pierceCount)
        end)

        it("should initialize with 1 projectile count", function()
            assert.is.equal(1, ability.projectileCount)
        end)
    end)

    -- **Validates: Requirements 2.2**
    -- Test canActivate respects cooldown
    describe("canActivate", function()
        it("should return true when cooldown has elapsed", function()
            ability.lastActivation = 0
            local currentTime = 1.0
            assert.is_true(ability:canActivate(currentTime))
        end)

        it("should return false when cooldown has not elapsed", function()
            ability.lastActivation = 0
            local currentTime = 0.5
            assert.is_false(ability:canActivate(currentTime))
        end)

        it("should return true when exactly at cooldown threshold", function()
            ability.lastActivation = 0
            local currentTime = 1.0
            assert.is_true(ability:canActivate(currentTime))
        end)

        it("should return true when time exceeds cooldown", function()
            ability.lastActivation = 0
            local currentTime = 2.5
            assert.is_true(ability:canActivate(currentTime))
        end)

        it("should work with non-zero lastActivation time", function()
            ability.lastActivation = 5.0
            local currentTime = 6.0
            assert.is_true(ability:canActivate(currentTime))
        end)

        it("should return false when time difference is less than cooldown", function()
            ability.lastActivation = 5.0
            local currentTime = 5.8
            assert.is_false(ability:canActivate(currentTime))
        end)

        it("should respect modified cooldown after upgrade", function()
            ability.cooldown = 0.5
            ability.lastActivation = 0
            local currentTime = 0.5
            assert.is_true(ability:canActivate(currentTime))
        end)
    end)

    -- **Validates: Requirements 2.3**
    -- Test findNearestEnemy returns closest enemy
    describe("findNearestEnemy", function()
        it("should return nil when enemies array is empty", function()
            local enemies = {}
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is_nil(result)
        end)

        it("should return nil when enemies array is nil", function()
            local result = ability:findNearestEnemy(100, 100, nil)
            assert.is_nil(result)
        end)

        it("should return the only enemy when there is one", function()
            local enemy = { x = 200, y = 200, isActive = true }
            local enemies = { enemy }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is.equal(enemy, result)
        end)

        it("should return the closest enemy when there are multiple", function()
            local enemy1 = { x = 200, y = 200, isActive = true }  -- Distance: sqrt(100^2 + 100^2) = 141.42
            local enemy2 = { x = 150, y = 150, isActive = true }  -- Distance: sqrt(50^2 + 50^2) = 70.71
            local enemy3 = { x = 300, y = 300, isActive = true }  -- Distance: sqrt(200^2 + 200^2) = 282.84
            local enemies = { enemy1, enemy2, enemy3 }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is.equal(enemy2, result)
        end)

        it("should ignore inactive enemies", function()
            local enemy1 = { x = 150, y = 150, isActive = false }  -- Closest but inactive
            local enemy2 = { x = 200, y = 200, isActive = true }   -- Active
            local enemies = { enemy1, enemy2 }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is.equal(enemy2, result)
        end)

        it("should return nil when all enemies are inactive", function()
            local enemy1 = { x = 150, y = 150, isActive = false }
            local enemy2 = { x = 200, y = 200, isActive = false }
            local enemies = { enemy1, enemy2 }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is_nil(result)
        end)

        it("should handle enemies at the same position as hero", function()
            local enemy = { x = 100, y = 100, isActive = true }
            local enemies = { enemy }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is.equal(enemy, result)
        end)

        it("should calculate distance correctly for horizontal separation", function()
            local enemy1 = { x = 200, y = 100, isActive = true }  -- Distance: 100
            local enemy2 = { x = 250, y = 100, isActive = true }  -- Distance: 150
            local enemies = { enemy1, enemy2 }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is.equal(enemy1, result)
        end)

        it("should calculate distance correctly for vertical separation", function()
            local enemy1 = { x = 100, y = 200, isActive = true }  -- Distance: 100
            local enemy2 = { x = 100, y = 300, isActive = true }  -- Distance: 200
            local enemies = { enemy1, enemy2 }
            local result = ability:findNearestEnemy(100, 100, enemies)
            assert.is.equal(enemy1, result)
        end)
    end)

    -- **Validates: Requirements 2.1, 2.2, 2.3**
    -- Test activate creates projectiles
    describe("activate", function()
        local mockProjectilePool
        local mockProjectile

        before_each(function()
            mockProjectile = {
                activate = function() end
            }
            mockProjectilePool = {
                get = function() return mockProjectile end
            }
        end)

        it("should return false when no enemies exist", function()
            local enemies = {}
            local result = ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is_false(result)
        end)

        it("should return false when all enemies are inactive", function()
            local enemies = {
                { x = 200, y = 200, isActive = false }
            }
            local result = ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is_false(result)
        end)

        it("should return true when activation succeeds", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            local result = ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is_true(result)
        end)

        it("should update lastActivation time on successful activation", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            local initialTime = ability.lastActivation
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is_true(ability.lastActivation > initialTime)
        end)

        it("should create one projectile by default", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            local projectileCount = 0
            mockProjectilePool.get = function()
                projectileCount = projectileCount + 1
                return mockProjectile
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(1, projectileCount)
        end)

        it("should create multiple projectiles when projectileCount is upgraded", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            ability.projectileCount = 3
            local projectileCount = 0
            mockProjectilePool.get = function()
                projectileCount = projectileCount + 1
                return mockProjectile
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(3, projectileCount)
        end)

        it("should activate projectile with correct hero position", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            local activatedHeroX, activatedHeroY
            mockProjectile.activate = function(self, heroX, heroY)
                activatedHeroX = heroX
                activatedHeroY = heroY
            end
            ability:activate(150, 250, enemies, mockProjectilePool)
            assert.is.equal(150, activatedHeroX)
            assert.is.equal(250, activatedHeroY)
        end)

        it("should activate projectile with correct target position", function()
            local enemy = { x = 300, y = 400, isActive = true }
            local enemies = { enemy }
            local activatedTargetX, activatedTargetY
            mockProjectile.activate = function(self, heroX, heroY, targetX, targetY)
                activatedTargetX = targetX
                activatedTargetY = targetY
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(300, activatedTargetX)
            assert.is.equal(400, activatedTargetY)
        end)

        it("should activate projectile with correct speed", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            local activatedSpeed
            mockProjectile.activate = function(self, heroX, heroY, targetX, targetY, speed)
                activatedSpeed = speed
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(400, activatedSpeed)
        end)

        it("should activate projectile with correct damage", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            local activatedDamage
            mockProjectile.activate = function(self, heroX, heroY, targetX, targetY, speed, damage)
                activatedDamage = damage
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(10, activatedDamage)
        end)

        it("should activate projectile with correct pierce count", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            ability.pierceCount = 2
            local activatedPierce
            mockProjectile.activate = function(self, heroX, heroY, targetX, targetY, speed, damage, pierce)
                activatedPierce = pierce
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(2, activatedPierce)
        end)

        it("should target the nearest enemy when multiple exist", function()
            local enemy1 = { x = 300, y = 300, isActive = true }  -- Farther
            local enemy2 = { x = 150, y = 150, isActive = true }  -- Closer
            local enemies = { enemy1, enemy2 }
            local activatedTargetX, activatedTargetY
            mockProjectile.activate = function(self, heroX, heroY, targetX, targetY)
                activatedTargetX = targetX
                activatedTargetY = targetY
            end
            ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is.equal(150, activatedTargetX)
            assert.is.equal(150, activatedTargetY)
        end)

        it("should handle nil projectile from pool gracefully", function()
            local enemies = {
                { x = 200, y = 200, isActive = true }
            }
            mockProjectilePool.get = function() return nil end
            local result = ability:activate(100, 100, enemies, mockProjectilePool)
            assert.is_true(result)  -- Still returns true even if projectile creation fails
        end)
    end)

    -- **Validates: Requirements 2.7**
    -- Test upgrade applies tier bonuses correctly
    describe("upgrade", function()
        it("should increase damage by 5 for damage_increase upgrade", function()
            local initialDamage = ability.damage
            ability:upgrade("damage_increase")
            assert.is.equal(initialDamage + 5, ability.damage)
        end)

        it("should increment tier for damage_increase upgrade", function()
            local initialTier = ability.tier
            ability:upgrade("damage_increase")
            assert.is.equal(initialTier + 1, ability.tier)
        end)

        it("should reduce cooldown by 0.15 for attack_speed upgrade", function()
            local initialCooldown = ability.cooldown
            ability:upgrade("attack_speed")
            assert.is.equal(initialCooldown - 0.15, ability.cooldown)
        end)

        it("should not reduce cooldown below 0.25 seconds", function()
            ability.cooldown = 0.3
            ability:upgrade("attack_speed")
            assert.is.equal(0.25, ability.cooldown)
        end)

        it("should maintain minimum cooldown of 0.25 when already at minimum", function()
            ability.cooldown = 0.25
            ability:upgrade("attack_speed")
            assert.is.equal(0.25, ability.cooldown)
        end)

        it("should increment tier for attack_speed upgrade", function()
            local initialTier = ability.tier
            ability:upgrade("attack_speed")
            assert.is.equal(initialTier + 1, ability.tier)
        end)

        it("should increase projectileCount by 1 for projectile_count upgrade", function()
            local initialCount = ability.projectileCount
            ability:upgrade("projectile_count")
            assert.is.equal(initialCount + 1, ability.projectileCount)
        end)

        it("should increment tier for projectile_count upgrade", function()
            local initialTier = ability.tier
            ability:upgrade("projectile_count")
            assert.is.equal(initialTier + 1, ability.tier)
        end)

        it("should increase pierceCount by 1 for pierce upgrade", function()
            local initialPierce = ability.pierceCount
            ability:upgrade("pierce")
            assert.is.equal(initialPierce + 1, ability.pierceCount)
        end)

        it("should increment tier for pierce upgrade", function()
            local initialTier = ability.tier
            ability:upgrade("pierce")
            assert.is.equal(initialTier + 1, ability.tier)
        end)

        it("should not exceed tier 5", function()
            ability.tier = 5
            ability:upgrade("damage_increase")
            assert.is.equal(5, ability.tier)
        end)

        it("should apply multiple upgrades cumulatively", function()
            ability:upgrade("damage_increase")
            ability:upgrade("damage_increase")
            ability:upgrade("attack_speed")
            assert.is.equal(20, ability.damage)
            assert.is.equal(0.85, ability.cooldown)
            assert.is.equal(4, ability.tier)
        end)

        it("should handle unknown upgrade type gracefully", function()
            local initialDamage = ability.damage
            local initialTier = ability.tier
            ability:upgrade("unknown_upgrade")
            assert.is.equal(initialDamage, ability.damage)
            assert.is.equal(initialTier, ability.tier)
        end)

        it("should allow mixing different upgrade types", function()
            ability:upgrade("damage_increase")
            ability:upgrade("projectile_count")
            ability:upgrade("pierce")
            assert.is.equal(15, ability.damage)
            assert.is.equal(2, ability.projectileCount)
            assert.is.equal(1, ability.pierceCount)
            assert.is.equal(4, ability.tier)
        end)
    end)

    -- **Validates: Requirements 2.8**
    -- Property 4: Ability Cooldown Independence
    describe("Property 4: Ability Cooldown Independence", function()
        local generators = require("tests.generators.game_generators")

        it("should not affect other abilities' cooldown timers when one ability is activated", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Generate random number of abilities (2-5)
                local abilityCount = math.random(2, 5)

                -- Create a hero with multiple abilities
                local Hero = require("src.entities.hero")
                local hero = Hero:new(360, 1180)

                -- Create and add multiple ArcaneBolt abilities (simulating different abilities)
                local abilities = {}
                for i = 1, abilityCount do
                    local ability = ArcaneBolt:new()
                    -- Give each ability a unique cooldown to make them distinguishable
                    ability.cooldown = 1.0 + (i * 0.1)
                    -- Set random lastActivation times (in the past so they can activate)
                    ability.lastActivation = 0
                    hero:addAbility(ability)
                    table.insert(abilities, ability)
                end

                -- Create mock projectile pool
                local mockProjectile = {
                    activate = function() end
                }
                local mockProjectilePool = {
                    get = function() return mockProjectile end
                }

                -- Create mock enemies
                local enemies = {
                    { x = 200, y = 200, isActive = true }
                }

                -- Select a random ability to activate
                local abilityToActivate = math.random(1, abilityCount)

                -- Store the state of all abilities before activation
                local statesBefore = {}
                for i, ability in ipairs(abilities) do
                    statesBefore[i] = {
                        lastActivation = ability.lastActivation,
                        cooldown = ability.cooldown,
                        damage = ability.damage,
                        tier = ability.tier,
                        pierceCount = ability.pierceCount,
                        projectileCount = ability.projectileCount
                    }
                end

                -- Activate the selected ability
                local activationResult = abilities[abilityToActivate]:activate(hero.x, hero.y, enemies, mockProjectilePool)

                -- Verify activation succeeded
                assert.is_true(activationResult, "Ability activation should succeed")

                -- Verify that only the activated ability's lastActivation changed
                for i, ability in ipairs(abilities) do
                    if i == abilityToActivate then
                        -- The activated ability should have updated lastActivation
                        assert.is_true(ability.lastActivation >= statesBefore[i].lastActivation,
                            "Activated ability should have updated or maintained lastActivation")
                    else
                        -- All other abilities should remain unchanged
                        assert.are.equal(statesBefore[i].lastActivation, ability.lastActivation,
                            "Non-activated ability " .. i .. " lastActivation should not change")
                        assert.are.equal(statesBefore[i].cooldown, ability.cooldown,
                            "Non-activated ability " .. i .. " cooldown should not change")
                        assert.are.equal(statesBefore[i].damage, ability.damage,
                            "Non-activated ability " .. i .. " damage should not change")
                        assert.are.equal(statesBefore[i].tier, ability.tier,
                            "Non-activated ability " .. i .. " tier should not change")
                        assert.are.equal(statesBefore[i].pierceCount, ability.pierceCount,
                            "Non-activated ability " .. i .. " pierceCount should not change")
                        assert.are.equal(statesBefore[i].projectileCount, ability.projectileCount,
                            "Non-activated ability " .. i .. " projectileCount should not change")
                    end
                end

                -- Cleanup
                hero:destroy()
            end
        end)
    end)

    -- **Validates: Requirements 2.3**
    -- Property 5: Nearest Enemy Targeting
    describe("Property 5: Nearest Enemy Targeting", function()
        it("should fire projectile toward the enemy with minimum distance to hero", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Generate random hero position within game area
                local heroX = math.random(100, 620)
                local heroY = math.random(200, 1180)

                -- Generate random number of enemies (2-10)
                local enemyCount = math.random(2, 10)

                -- Create enemies at random positions
                local enemies = {}
                for i = 1, enemyCount do
                    table.insert(enemies, {
                        x = math.random(50, 670),
                        y = math.random(50, 1000),
                        isActive = true
                    })
                end

                -- Calculate which enemy is actually nearest
                local nearestEnemy = nil
                local minDistance = math.huge
                for _, enemy in ipairs(enemies) do
                    local dx = enemy.x - heroX
                    local dy = enemy.y - heroY
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < minDistance then
                        minDistance = distance
                        nearestEnemy = enemy
                    end
                end

                -- Track which target the projectile was fired at
                local firedTargetX, firedTargetY

                -- Create mock projectile pool that captures the target
                local mockProjectile = {
                    activate = function(self, pHeroX, pHeroY, targetX, targetY)
                        firedTargetX = targetX
                        firedTargetY = targetY
                    end
                }
                local mockProjectilePool = {
                    get = function() return mockProjectile end
                }

                -- Activate the ability
                ability:activate(heroX, heroY, enemies, mockProjectilePool)

                -- Verify the projectile was fired at the nearest enemy
                assert.are.equal(nearestEnemy.x, firedTargetX,
                    "Projectile should target nearest enemy X coordinate")
                assert.are.equal(nearestEnemy.y, firedTargetY,
                    "Projectile should target nearest enemy Y coordinate")
            end
        end)

        it("should consistently target nearest enemy across multiple projectiles", function()
            -- Test that when projectileCount > 1, all projectiles target the same nearest enemy
            for _ = 1, 50 do
                -- Set up ability with multiple projectiles
                ability.projectileCount = math.random(2, 5)

                -- Generate random hero position
                local heroX = math.random(100, 620)
                local heroY = math.random(200, 1180)

                -- Create multiple enemies
                local enemies = {}
                for i = 1, math.random(3, 8) do
                    table.insert(enemies, {
                        x = math.random(50, 670),
                        y = math.random(50, 1000),
                        isActive = true
                    })
                end

                -- Calculate nearest enemy
                local nearestEnemy = nil
                local minDistance = math.huge
                for _, enemy in ipairs(enemies) do
                    local dx = enemy.x - heroX
                    local dy = enemy.y - heroY
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < minDistance then
                        minDistance = distance
                        nearestEnemy = enemy
                    end
                end

                -- Track all projectile targets
                local projectileTargets = {}

                -- Create mock projectile pool
                local mockProjectile = {
                    activate = function(self, pHeroX, pHeroY, targetX, targetY)
                        table.insert(projectileTargets, { x = targetX, y = targetY })
                    end
                }
                local mockProjectilePool = {
                    get = function() return mockProjectile end
                }

                -- Activate the ability
                ability:activate(heroX, heroY, enemies, mockProjectilePool)

                -- Verify all projectiles targeted the same nearest enemy
                assert.are.equal(ability.projectileCount, #projectileTargets,
                    "Should create correct number of projectiles")

                for i, target in ipairs(projectileTargets) do
                    assert.are.equal(nearestEnemy.x, target.x,
                        "Projectile " .. i .. " should target nearest enemy X")
                    assert.are.equal(nearestEnemy.y, target.y,
                        "Projectile " .. i .. " should target nearest enemy Y")
                end

                -- Reset projectileCount for next iteration
                ability.projectileCount = 1
            end
        end)

        it("should ignore inactive enemies when finding nearest target", function()
            -- Test that inactive enemies are not considered for targeting
            for _ = 1, 50 do
                -- Generate random hero position
                local heroX = math.random(100, 620)
                local heroY = math.random(200, 1180)

                -- Create enemies with mix of active and inactive
                local enemies = {}
                local activeEnemies = {}

                -- Add some inactive enemies (potentially closer)
                for i = 1, math.random(1, 3) do
                    table.insert(enemies, {
                        x = math.random(50, 670),
                        y = math.random(50, 1000),
                        isActive = false
                    })
                end

                -- Add active enemies
                for i = 1, math.random(2, 5) do
                    local enemy = {
                        x = math.random(50, 670),
                        y = math.random(50, 1000),
                        isActive = true
                    }
                    table.insert(enemies, enemy)
                    table.insert(activeEnemies, enemy)
                end

                -- Calculate nearest active enemy
                local nearestActiveEnemy = nil
                local minDistance = math.huge
                for _, enemy in ipairs(activeEnemies) do
                    local dx = enemy.x - heroX
                    local dy = enemy.y - heroY
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < minDistance then
                        minDistance = distance
                        nearestActiveEnemy = enemy
                    end
                end

                -- Track which target the projectile was fired at
                local firedTargetX, firedTargetY

                -- Create mock projectile pool
                local mockProjectile = {
                    activate = function(self, pHeroX, pHeroY, targetX, targetY)
                        firedTargetX = targetX
                        firedTargetY = targetY
                    end
                }
                local mockProjectilePool = {
                    get = function() return mockProjectile end
                }

                -- Activate the ability
                ability:activate(heroX, heroY, enemies, mockProjectilePool)

                -- Verify the projectile targeted the nearest active enemy
                assert.are.equal(nearestActiveEnemy.x, firedTargetX,
                    "Should target nearest active enemy X, ignoring inactive enemies")
                assert.are.equal(nearestActiveEnemy.y, firedTargetY,
                    "Should target nearest active enemy Y, ignoring inactive enemies")
            end
        end)
    end)
end)
