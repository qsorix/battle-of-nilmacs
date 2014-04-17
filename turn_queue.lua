turn_queue = {}

function turn_queue.enqueue(queue, object, turn)
    if not queue[turn] then
        queue[turn] = {}
    end
    queue[turn][object] = true
end

function turn_queue.dequeue(queue, priority)
    while not queue[priority] do
        priority = priority + 1
    end
    local result = queue[priority]
    queue[priority] = nil
    return result, priority
end

function turn_queue.remove(queue, object)
    for i, list in pairs(queue) do
        list[object] = nil
        if not next(list, nil) then
            -- remove empty tables
            queue[i] = nil
        end
    end
end

return turn_queue
