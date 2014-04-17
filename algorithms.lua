local ipairs = ipairs
local math = math

module(...)

function distance(a, b)
    return math.max(math.abs(a.x-b.x), math.abs(a.y-b.y))
end

function closest(species, self, others)
    local dist = 1000
    local dx, dy, cr
    for _, c in ipairs(others) do
        if c.species == species then
            local ndist = (c.x-self.x)+(c.y-self.y)
            if ndist < dist then
                dx = c.x-self.x
                dy = c.y-self.y
                dist = ndist
                cr = c
            end
        end
    end
    return dx, dy, cr
end

function closest_alive(species, self, others)
    local dist = 1000
    local dx, dy, cr
    for _, c in ipairs(others) do
        if c.species == species and c.alive then
            local ndist = distance(c, self)
            if ndist < dist then
                dx = c.x-self.x
                dy = c.y-self.y
                dist = ndist
                cr = c
            end
        end
    end
    return dx, dy, cr
end

function away_from(dx, dy)
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then
            return {dx=-1, dy=0}
        else
            return {dx=1, dy=0}
        end
    else
        if dy > 0 then
            return {dx=0, dy=-1}
        else
            return {dx=0, dy=1}
        end
    end
end

function closer_to(dx, dy)
    local away = away_from(dx, dy)
    if away then
        return {dx=-away.dx, dy=-away.dy}
    end
end


