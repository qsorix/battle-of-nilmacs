require "lunit"
TQ = require "turn_queue"

module("test_turn_queue", lunit.testcase, package.seeall)

local function size(table)
    local count = 0
    for a, b in pairs(table) do
        count = count + 1
    end
    return count
end

function test_enqueue_adds_element_at_their_turn()
    local q = {}
    TQ.enqueue(q, "foo", 5)

    assert_table(q[5])
    assert_true(q[5]["foo"])
    assert_equal(1, size(q))
    assert_equal(1, size(q[5]))
end

function test_enqueue_adds_more_elements()
    local q = {}
    TQ.enqueue(q, "foo", 5)
    TQ.enqueue(q, "bar", 5)
    TQ.enqueue(q, "qux", 6)

    assert_table(q[5])
    assert_table(q[6])
    assert_true(q[5]["foo"])
    assert_true(q[5]["bar"])
    assert_true(q[6]["qux"])
    assert_equal(2, size(q))
    assert_equal(2, size(q[5]))
    assert_equal(1, size(q[6]))
end

function test_dequeue_removes_elements_for_earliest_turn()
    local q = {}
    TQ.enqueue(q, "foo", 5)
    TQ.enqueue(q, "bar", 5)
    TQ.enqueue(q, "qux", 6)
    local elements, turn = TQ.dequeue(q, 3)

    -- check returned stuff
    assert_table(elements)
    assert_equal(5, turn)
    assert_equal(2, size(elements))
    assert_true(elements["foo"])
    assert_true(elements["bar"])

    -- check that it's gone from the queue
    assert_nil(q[5])
    assert_equal(1, size(q))
    assert_table(q[6])
end

function test_remove_drops_elements()
    local q = {}
    TQ.enqueue(q, "foo", 7)
    TQ.enqueue(q, "bar", 7)
    TQ.remove(q, "foo")

    assert_table(q[7])
    assert_nil(q[7]["foo"])
    assert_true(q[7]["bar"])

    assert_equal(1, size(q[7]))
end

function test_remove_drops_turns_when_last_element_is_removed()
    local q = {}
    TQ.enqueue(q, "foo", 7)
    TQ.remove(q, "foo")

    assert_nil(q[7])
end
