require("tests.spec_helper")
local Projectile = require("src.entities.projectile")

describe("Projectile Entity", function()
    local projectile

    before_each(function()
        projectile = Projectile:new()
    end)

    after_each(function()
        if projectile and projectile.destroy then
            projectile:destroy()
        end
        projectile = nil
    end)

    describe("initialization", function()
        it("should initialize with position at origin", function()
            assert.is.equal(0, projectile.x)
            assert.is.equal(0, projectile.y)
        end)

        it("should initialize with zero velocity", function()
            assert.is.equal(0, projectile.vx)
            assert.is.equal(0, projectile.vy)
        end)

        it("should initialize with zero damage", function()
            assert.is.equal(0, projectile.damage)
        end)

        it("should initialize with zero pierce count", function()
            assert.is.equal(0, projectile.pierceCount)
        end)

        it("should initialize as inactive", function()
            assert.is_false(projectile.isActive)
        end)

        it("should initialize with empty hitEnemies table", function()
            assert.is_not_nil(projectile.hitEnemies)
            assert.is.equal(0, #projectile.hitEnemies)
        end)

        it("should initialize with nil display object", function()
            assert.is_nil(projectile.displayObject)
        end)
    end)

    -- **Validates: Requirements 2.4**
    -- Test activate calculates correct velocity vector
    describe("activate", function()
        it("should set position to spawn coordinates", function()
            projectile:activate(100, 200, 300, 400, 500, 10, 0)
            assert.is.equal(100, projectile.x)
            assert.is.equal(200, projectile.y)
        end)

        it("should calculate velocity vector toward target", function()
            -- Spawn at (0, 0), target at (3, 4), speed 500
            -- Distance = 5, normalized = (0.6, 0.8)
            -- Velocity = (300, 400)
            projectile:activate(0, 0, 3, 4, 500, 10, 0)
            assert.is.equal(300, projectile.vx)
            assert.is.equal(400, projectile.vy)
        end)

        it("should calculate velocity for horizontal movement", function()
            -- Spawn at (0, 0), target at (10, 0), speed 100
            projectile:activate(0, 0, 10, 0, 100, 10, 0)
            assert.is.equal(100, projectile.vx)
            assert.is.equal(0, projectile.vy)
        end)

        it("should calculate velocity for vertical movement", function()
            -- Spawn at (0, 0), target at (0, 10), speed 100
            projectile:activate(0, 0, 0, 10, 100, 10, 0)
            assert.is.equal(0, projectile.vx)
            assert.is.equal(100, projectile.vy)
        end)

        it("should calculate velocity for diagonal movement", function()
            -- Spawn at (0, 0), target at (1, 1), speed 100
            -- Distance = sqrt(2), normalized = (1/sqrt(2), 1/sqrt(2))
            -- Velocity = (100/sqrt(2), 100/sqrt(2)) ≈ (70.71, 70.71)
            projectile:activate(0, 0, 1, 1, 100, 10, 0)
            local expected = 100 / math.sqrt(2)
            assert.is.near(expected, projectile.vx, 0.01)
            assert.is.near(expected, projectile.vy, 0.01)
        end)

        it("should default to upward velocity when target is at same position", function()
            projectile:activate(100, 100, 100, 100, 200, 10, 0)
            assert.is.equal(0, projectile.vx)
            assert.is.equal(-200, projectile.vy)
        end)

        it("should set damage property", function()
            projectile:activate(0, 0, 100, 100, 500, 25, 0)
            assert.is.equal(25, projectile.damage)
        end)

        it("should set pierce count property", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 3)
            assert.is.equal(3, projectile.pierceCount)
        end)

        it("should reset hitEnemies table", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            table.insert(projectile.hitEnemies, "enemy1")
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            assert.is.equal(0, #projectile.hitEnemies)
        end)

        it("should set isActive to true", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            assert.is_true(projectile.isActive)
        end)

        it("should create display object on first activation", function()
            projectile:activate(100, 200, 300, 400, 500, 10, 0)
            assert.is_not_nil(projectile.displayObject)
            assert.is.equal(100, projectile.displayObject.x)
            assert.is.equal(200, projectile.displayObject.y)
        end)

        it("should reuse display object on subsequent activations", function()
            projectile:activate(100, 200, 300, 400, 500, 10, 0)
            local firstDisplayObj = projectile.displayObject
            projectile:deactivate()
            projectile:activate(200, 300, 400, 500, 500, 10, 0)
            assert.is.equal(firstDisplayObj, projectile.displayObject)
            assert.is.equal(200, projectile.displayObject.x)
            assert.is.equal(300, projectile.displayObject.y)
        end)

        it("should make display object visible", function()
            projectile:activate(100, 200, 300, 400, 500, 10, 0)
            projectile:deactivate()
            projectile:activate(200, 300, 400, 500, 500, 10, 0)
            assert.is_true(projectile.displayObject.isVisible)
        end)
    end)

    -- **Validates: Requirements 2.4**
    -- Test update moves projectile correctly
    describe("update", function()
        it("should move projectile by velocity * dt", function()
            projectile:activate(0, 0, 100, 0, 100, 10, 0)
            -- vx = 100, vy = 0
            projectile:update(1.0)
            assert.is.equal(100, projectile.x)
            assert.is.equal(0, projectile.y)
        end)

        it("should move projectile correctly with small dt", function()
            projectile:activate(0, 0, 100, 0, 100, 10, 0)
            -- vx = 100, vy = 0
            projectile:update(0.016)
            assert.is.equal(1.6, projectile.x)
            assert.is.equal(0, projectile.y)
        end)

        it("should accumulate movement over multiple updates", function()
            projectile:activate(0, 0, 100, 0, 100, 10, 0)
            -- vx = 100, vy = 0
            projectile:update(0.5)
            projectile:update(0.5)
            projectile:update(0.5)
            assert.is.equal(150, projectile.x)
            assert.is.equal(0, projectile.y)
        end)

        it("should move in both X and Y directions", function()
            -- Spawn at (0, 0), target at (3, 4), speed 500
            -- vx = 300, vy = 400
            projectile:activate(0, 0, 3, 4, 500, 10, 0)
            projectile:update(1.0)
            assert.is.equal(300, projectile.x)
            assert.is.equal(400, projectile.y)
        end)

        it("should update display object position", function()
            projectile:activate(0, 0, 100, 0, 100, 10, 0)
            projectile:update(1.0)
            assert.is.equal(100, projectile.displayObject.x)
            assert.is.equal(0, projectile.displayObject.y)
        end)

        it("should not move when inactive", function()
            projectile:activate(0, 0, 100, 0, 100, 10, 0)
            projectile:deactivate()
            local initialX = projectile.x
            local initialY = projectile.y
            projectile:update(1.0)
            assert.is.equal(initialX, projectile.x)
            assert.is.equal(initialY, projectile.y)
        end)

        it("should deactivate when projectile goes off screen", function()
            projectile:activate(0, 0, -1000, 0, 500, 10, 0)
            -- vx = -500, vy = 0
            projectile:update(1.0)
            -- x = -500, which is off screen
            assert.is_false(projectile.isActive)
        end)
    end)

    -- **Validates: Requirements 2.6**
    -- Test isOffScreen detects boundaries
    describe("isOffScreen", function()
        it("should return false when projectile is within bounds", function()
            projectile:activate(360, 640, 400, 700, 100, 10, 0)
            assert.is_false(projectile:isOffScreen())
        end)

        it("should return true when projectile is left of screen", function()
            projectile.x = -250
            projectile.y = 640
            assert.is_true(projectile:isOffScreen())
        end)

        it("should return true when projectile is right of screen", function()
            projectile.x = 950
            projectile.y = 640
            assert.is_true(projectile:isOffScreen())
        end)

        it("should return true when projectile is above screen", function()
            projectile.x = 360
            projectile.y = -250
            assert.is_true(projectile:isOffScreen())
        end)

        it("should return true when projectile is below screen", function()
            projectile.x = 360
            projectile.y = 1500
            assert.is_true(projectile:isOffScreen())
        end)

        it("should return false when projectile is at left boundary with buffer", function()
            projectile.x = -199
            projectile.y = 640
            assert.is_false(projectile:isOffScreen())
        end)

        it("should return false when projectile is at right boundary with buffer", function()
            projectile.x = 919
            projectile.y = 640
            assert.is_false(projectile:isOffScreen())
        end)

        it("should return false when projectile is at top boundary with buffer", function()
            projectile.x = 360
            projectile.y = -199
            assert.is_false(projectile:isOffScreen())
        end)

        it("should return false when projectile is at bottom boundary with buffer", function()
            projectile.x = 360
            projectile.y = 1479
            assert.is_false(projectile:isOffScreen())
        end)

        it("should return true when projectile is exactly at left boundary", function()
            projectile.x = -200
            projectile.y = 640
            assert.is_false(projectile:isOffScreen())
        end)

        it("should return true when projectile is beyond left boundary", function()
            projectile.x = -201
            projectile.y = 640
            assert.is_true(projectile:isOffScreen())
        end)
    end)

    -- **Validates: Requirements 2.6**
    -- Test pierce behavior (hitEnemies tracking)
    describe("pierce behavior", function()
        it("should track hit enemies", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            projectile:onHit(enemy1)
            assert.is.equal(1, #projectile.hitEnemies)
            assert.is.equal(enemy1, projectile.hitEnemies[1])
        end)

        it("should not hit the same enemy twice", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            local result1 = projectile:onHit(enemy1)
            local result2 = projectile:onHit(enemy1)
            assert.is_true(result1)
            assert.is_false(result2)
            assert.is.equal(1, #projectile.hitEnemies)
        end)

        it("should decrement pierce count on hit", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            projectile:onHit(enemy1)
            assert.is.equal(1, projectile.pierceCount)
        end)

        it("should allow hitting multiple different enemies with pierce", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            local enemy2 = { id = "enemy2" }
            projectile:onHit(enemy1)
            projectile:onHit(enemy2)
            assert.is.equal(2, #projectile.hitEnemies)
            assert.is_true(projectile.isActive)
            assert.is.equal(0, projectile.pierceCount)
        end)

        it("should deactivate after hitting pierce+1 enemies", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            local enemy2 = { id = "enemy2" }
            local enemy3 = { id = "enemy3" }
            projectile:onHit(enemy1)
            projectile:onHit(enemy2)
            assert.is_true(projectile.isActive)
            projectile:onHit(enemy3)
            assert.is_false(projectile.isActive)
        end)

        it("should deactivate when pierce count reaches -1", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            local enemy1 = { id = "enemy1" }
            projectile:onHit(enemy1)
            assert.is_false(projectile.isActive)
        end)

        it("should not deactivate while pierce count is positive", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            local enemy2 = { id = "enemy2" }
            projectile:onHit(enemy1)
            projectile:onHit(enemy2)
            assert.is_true(projectile.isActive)
            assert.is.equal(0, projectile.pierceCount)
        end)

        it("should return false when hitting while inactive", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            projectile:deactivate()
            local enemy1 = { id = "enemy1" }
            local result = projectile:onHit(enemy1)
            assert.is_false(result)
        end)

        it("should clear hitEnemies on deactivate", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            projectile:onHit(enemy1)
            projectile:deactivate()
            assert.is.equal(0, #projectile.hitEnemies)
        end)
    end)

    describe("deactivate", function()
        it("should set isActive to false", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            projectile:deactivate()
            assert.is_false(projectile.isActive)
        end)

        it("should hide display object", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            projectile:deactivate()
            assert.is_false(projectile.displayObject.isVisible)
        end)

        it("should clear hitEnemies table", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 2)
            local enemy1 = { id = "enemy1" }
            projectile:onHit(enemy1)
            projectile:deactivate()
            assert.is.equal(0, #projectile.hitEnemies)
        end)

        it("should handle deactivation when display object is nil", function()
            projectile:deactivate()
            assert.is_false(projectile.isActive)
        end)
    end)

    describe("destroy", function()
        it("should remove display object", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            projectile:destroy()
            assert.is_nil(projectile.displayObject)
        end)

        it("should handle destroy when display object is nil", function()
            projectile:destroy()
            assert.is_nil(projectile.displayObject)
        end)

        it("should handle multiple destroy calls safely", function()
            projectile:activate(0, 0, 100, 100, 500, 10, 0)
            projectile:destroy()
            projectile:destroy()
            assert.is_nil(projectile.displayObject)
        end)
    end)

    -- **Validates: Requirements 2.4**
    -- Property 6: Projectile Velocity
    describe("Property 6: Projectile Velocity", function()
        it("should have velocity magnitude equal to 400 pixels per second for Arcane Bolt", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Generate random spawn and target positions
                local spawnX = math.random(0, 720)
                local spawnY = math.random(0, 1280)
                local targetX = math.random(0, 720)
                local targetY = math.random(0, 1280)
                
                local projectile = Projectile:new()
                local arcaneBoltSpeed = 400  -- Arcane Bolt projectile speed
                
                -- Activate projectile with Arcane Bolt speed
                projectile:activate(spawnX, spawnY, targetX, targetY, arcaneBoltSpeed, 10, 0)
                
                -- Calculate velocity magnitude
                local velocityMagnitude = math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy)
                
                -- Velocity magnitude should equal the specified speed (400 px/s)
                -- Allow small floating point tolerance
                assert.is.near(arcaneBoltSpeed, velocityMagnitude, 0.01)
                
                -- Clean up
                projectile:destroy()
            end
        end)
        
        it("should maintain velocity direction toward target for any spawn and target positions", function()
            -- Run property test with 100 iterations
            for _ = 1, 100 do
                -- Generate random spawn and target positions
                local spawnX = math.random(0, 720)
                local spawnY = math.random(0, 1280)
                local targetX = math.random(0, 720)
                local targetY = math.random(0, 1280)
                
                local projectile = Projectile:new()
                local arcaneBoltSpeed = 400
                
                -- Activate projectile
                projectile:activate(spawnX, spawnY, targetX, targetY, arcaneBoltSpeed, 10, 0)
                
                -- Calculate expected direction vector
                local dx = targetX - spawnX
                local dy = targetY - spawnY
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance > 0 then
                    -- Expected normalized direction
                    local expectedDirX = dx / distance
                    local expectedDirY = dy / distance
                    
                    -- Actual normalized direction from velocity
                    local velocityMagnitude = math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy)
                    local actualDirX = projectile.vx / velocityMagnitude
                    local actualDirY = projectile.vy / velocityMagnitude
                    
                    -- Direction should match (with small tolerance for floating point)
                    assert.is.near(expectedDirX, actualDirX, 0.01)
                    assert.is.near(expectedDirY, actualDirY, 0.01)
                else
                    -- When spawn and target are same, should default to upward (-Y direction)
                    assert.is.equal(0, projectile.vx)
                    assert.is.equal(-arcaneBoltSpeed, projectile.vy)
                end
                
                -- Clean up
                projectile:destroy()
            end
        end)
    end)
end)
