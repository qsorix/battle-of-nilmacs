local species = {}
species.name = "foos"
species.display_letter = 'f'
species.display_color = 'yellow'
species.initial_energy = 400

local function only_bars(sees)
    local result = {}
    for _, c in ipairs(sees) do
        if c.name == "bars" then
            table.insert(result, c)
        end
    end
    return result
end

local function only_dead(sees)
    local result = {}
    for _, c in ipairs(sees) do
        if not c.alive then
            table.insert(result, c)
        end
    end
    return result
end

local function count_alive(sees)
    local result = 0
    for _, c in ipairs(sees) do
        if c.alive then
            result = result + 1
        end
    end
    return result
end

local function close_dead(Self, sees)
    local dead = only_dead(sees)
    local dx, dy, cr = Algo.closest("bars", Self, dead)
    return cr
end

function species.brain()
    local sees = Action.Look(15)
    sees = only_bars(sees)

    local food = close_dead(Self, sees)
    if food then
        return Decision.Eat(food)
    end

    if Self.energy > 650 then
        return Decision.Breed(400)
    end

    local living_bars = count_alive(sees)
    local should_eat = False
    if Self.energy < 20 then
        should_eat = True
    elseif Self.energy < 50 and living_bars > 2 then
        should_eat = True
    elseif Self.energy < 400 and living_bars > 4 then
        should_eat = True
    end

    if should_eat then
        local dx, dy, cr = closest("bars", Self, sees)

        if cr and (dx*dx+dy*dy < 4) then
            if cr.alive then
                return Decision.Attack(cr)
            else
                return Decision.Eat(cr)
            end
        end

        if (dx and dy) then
            return Decision.Move(closer_to(dx, dy))
        end
    end

    if not Self.memory.destination or
        (Self.x == Self.memory.destination.x and
         Self.y == Self.memory.destination.y)
    then
        Self.memory.destination = {}
        Self.memory.destination.x = math.random(1, World.X)
        Self.memory.destination.y = math.random(1, World.Y)
    end

    local dx = 0
    local dy = 0
    if Self.x < Self.memory.destination.x then
        dx = 1
    elseif Self.x > Self.memory.destination.x then
        dx = -1
    end
    if Self.y < Self.memory.destination.y then
        dy = 1
    elseif Self.y > Self.memory.destination.y then
        dy = -1
    end

    return Decision.Move({dx=dx,dy=dy})
end

return species
