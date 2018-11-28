local rdaneel = {
    VERSION = '0.1',
    _constants = {},
    _pri = {
        --  Workaround to Lua's nature that it's not possible to create
        --  constants
        protect = function ( tbl )
            return setmetatable( {}, {
                    __index = tbl,
                    __newindex = function( t, k, v )
                        error( "attempting to change constant " 
                                   .. tostring( k ) .. " to " .. tostring( v ), 2 )
                    end
            } )
        end,
    }
}

rdaneel._constants = { slotsNum = 16, }
rdaneel._constants = rdaneel._pri.protect( rdaneel._constants )

function turtle:goup ( destroy )
    if self and turtle.detectUp() then
        turtle.digUp()
    end
    turtle.up()
end

function turtle:godn ( destroy )
    if self and turtle.detectDown() then
        turtle.digDown()
    end
    turtle.down()
end

function turtle:gofd ( destroy )
    if self and turtle.detect() then
        turtle.dig()
    end
    turtle.forward()
end

function rdaneel:_turtleRepeat ( action, times )
    assert( action and type( action ) == 'function', 'action function must be specified' )
    local n
    if times then n = times else n = 1 end
    for _ = 1, n do action() end
end

function rdaneel:turtleTurnLeft ( times ) rdaneel:_turtleRepeat( turtle.turnLeft, times ) end
function rdaneel:turtleTurnRight ( times ) rdaneel:_turtleRepeat( turtle.turnRight, times ) end

function rdaneel:turtleGoUp ( times, destroy ) rdaneel:_turtleRepeat( function () turtle.goup( destroy ) end, times ) end
function rdaneel:turtleGoDown ( times, destroy ) rdaneel:_turtleRepeat( function () turtle.godn( destroy ) end, times ) end
function rdaneel:turtleGoForward ( times, destroy ) rdaneel:_turtleRepeat( function () turtle.gofd( destroy ) end, times ) end

function rdaneel:goBackOrigin ( x, y, direction )
    if direction == 1 then rdaneel:turtleTurnRight( 2 ) end
    if direction == 2 then rdaneel:turtleTurnRight()    end
    if direction == 4 then rdaneel:turtleTurnLeft()     end

    rdaneel:turtleGoForward( y + 1, true )
    rdaneel:turtleTurnRight()
    rdaneel:turtleGoForward( x, true )
    rdaneel:turtleTurnRight()
end

-- rdaneel:selectItem() selects the inventory slot with the names item,
-- returns `true` if found and `false` if not

function rdaneel:selectItem ( name )
    local currentSlot = turtle.getItemDetail( turtle.getSelectedSlot() )

    if currentSlot and currentSlot['name'] == name then
        return true
    end

    -- check all inventory slots

    local item = nil

    for slot = 1, rdaneel._constants.slotsNum do
        item = turtle.getItemDetail( slot )
        if item and item['name'] == name then
            return turtle.select( slot )
        end
    end

    return false -- couldn't find item
end

-- rdaneel:selectEmptySlot() selects inventory slot that is empty,
-- returns `true` if found, `false` if no empty spaces

function rdaneel:selectEmptySlot()
    if turtle.getItemCount( turtle.getSelectedSlot() ) == 0 then
        return true
    end

    -- loop through all slots
    for slot = 1, rdaneel._constants.slotsNum do
        if turtle.getItemSpace( slot ) == 64 then
            turtle.select( slot )
            return true
        end
    end

    return false -- couldn't find empty space
end

-- rdaneel:countInventory() returns the total number of items in the
-- inventory

function rdaneel:countInventory ()
    local total = 0

    for slot = 1, rdaneel._constants.slotsNum do
        total = total + turtle.getItemCount( slot )
    end

    return total
end

-- selectAndPlaceDown() selects a nonempty slot and places a
-- block from it under the turtle

function rdaneel:selectAndPlaceDown ( destroy )
    for slot = 1, rdaneel._constants.slotsNum do
        if turtle.getItemCount( slot ) > 0 then

            turtle.select( slot )

            local needToPlace = true
            local exists, details = turtle.inspectDown()

            if exists and destroy then
                if details.name == turtle.getItemDetail( turtle.getSelectedSlot() ).name then
                    needToPlace = false
                else
                    turtle.digDown()
                end
            elseif exists and not destroy then
                needToPlace = false
            end

            if needToPlace then
                turtle.placeDown()
            end

            return true
        end
    end

    return false
end

function rdaneel:sweepFlat ( length, width, sweepCallback )

    local minimum = length * width
    if turtle.getFuelLevel() < minimum then
        return false, 'HAVE NO ENOUGH FUEL'
    end

    local roundIdx = 0 -- Yes, we count the number of rounds from zero

    -- Instead of using an infinite loop, I'm waiting for a brief
    -- but elegant mathematical proof that is able to help us
    -- figure out in advance how exactly many rounds the turtle
    -- should move

    while true do
        local paths = nil

        local evenDelta = roundIdx * 2
        local oddDelta = evenDelta + 1

        --[[
                           right >
                     +-----------------+
                     | ^ ------------> |
                     | | ^ --------> | |
                     | | | + + + + | | |
               ^     | | | + + + + | | |  back
            forward  | | | ^ + + + | | |   v
                     | | | | + + + | | |
                     | | | | <-----v | |
                     | O <-----------v |
                     +-----------------+
                          < left
        ]]

        paths = {
            [1] = width  - evenDelta,         -- forward
            [2] = length - oddDelta,          -- right
            [3] = width  - oddDelta,          -- back
            [4] = length - ( evenDelta + 2 ), -- left
        }

        print( string.format( "Fd: %2d, Rt: %2d, Bk: %2d, Lt: %2d",
                              paths[1], paths[2], paths[3], paths[4] ) )

        -- Mark `done` as true in order to get rid of the nested
        -- loop.  Lua does not support goto-style statement until
        -- 5.2.0-beta-rc1

        local done = false

        if sweepCallback then
            assert( type( sweepCallback ) == 'function', 'Callback is required to be a function' )
        end

        local x = roundIdx
        local y = roundIdx - 1

        for direction, nsteps in ipairs( paths ) do
            local infoTbl = {
                round = roundIdx, direction = direction,
                steps = nil, x = nil, y = nil,
            }
            if nsteps == 0 then
                if sweepCallback then
                    infoTbl.x = x; infoTbl.y = y; infoTbl.steps = 0; infoTbl.done = true
                    sweepCallback( infoTbl )
                end
                done = true
                break
            else
                for n = 1, nsteps do turtle.gofd( true )
                    if sweepCallback then
                        if direction == 1 then
                            y = y + 1
                        elseif direction == 2 then
                            x = x + 1
                        elseif direction == 3 then
                            y = y - 1
                        elseif direction == 4 then
                            x = x - 1
                        end
                        infoTbl.x = x; infoTbl.y = y; infoTbl.steps = n
                        sweepCallback( infoTbl )
                    end
                end
                turtle.turnRight()
            end
        end

        if done then break end
        roundIdx = roundIdx + 1
    end
    return true
end

function rdaneel:sweepSolid ( params )

    local length, width = params.length, params.width
    assert( length and width, 'Length and width must be specified' )

    local height = params.height or 1
    local reversed = params.reversed or false
    local f = params.sweepCallback

    local from, to, step
    if reversed then
        from = height - 1; to = 0; step = -1
    else
        from = 0; to = height - 1; step = 1
    end

    -- lift turtle one more block so as to let turtle apply
    -- callback to the block underneath it:

    rdaneel:turtleGoUp( from + 1, true )

    for z = from, to, step do
        local success, err = rdaneel:sweepFlat(
            length, width,
            function ( info )
                info.z = z;
                if f then
                    assert( type( f ) == 'function', 'Callback is required to be a function' ) 
                    f( info )
                end
                if info.done then
                    rdaneel:goBackOrigin( info.x, info.y, info.direction )
                end
            end )

        if success then
            if reversed then
                turtle.godn( true )
            else
                turtle.goup( true )
            end
        else
            return success, err
        end

    end
    return true
end

--[[ rdaneel:rprint( table, [limit], [indent] )

    Recursively print arbitrary data. 
    Set limit (default 100) to stanch infinite loops.
]]
function rdaneel:rprint( tbl, lim, indent )
    local lim = lim or 100
    local indent = indent or ''

    if lim < 1 then error( 'ERROR: Item limit reached.' ) end

    local ts = type( tbl )
    if ts ~= 'table' then
        print( indent, ts, tbl )
        return result, lim - 1
    end

    print( indent, ts )

    -- print key-value pairs
    for k, v in pairs( tbl ) do
        _, lim = rdaneel:rprint( v, lim, indent .. '\t[' .. tostring( k ) .. ']' )
        if lim < 0 then
            break
        end
    end

    return result, lim
end	

logFH = fs.open( 'log', 'w' )
logFormat = "Round: %d; Dir: %d; X: %d; Y: %d; Z: %d; DONE: %s"

--[[ Print contents of `tbl`, with indentation.
    `indent` sets the initial level of indentation.
]]

result = ''
function rdaneel:tprint ( tbl, indent )
    if not indent then indent = 0 end
    for k, v in pairs( tbl ) do
        formatting = string.rep( "  ", indent ) .. k .. ": "
        if type( v ) == "table" then
            -- io.write( formatting .. "\n" )
            result = result .. formatting .. "\n"
            rdaneel:tprint( v, indent + 1 )
        else
            -- io.write( formatting .. v .. "\n" )
            result = result .. formatting .. v .. "\n"
        end
    end
end

tree = {}
success, err = rdaneel:sweepSolid {
    length = 4, width = 3, height = 3,
    reversed = false,
    sweepCallback = function ( info )
        -- Logging
        local log = string.format(
            logFormat, 
            info.round, info.direction, info.x, info.y, info.z, tostring( info.done ) )

        logFH.writeLine( log )

        local exists, details = turtle.inspectDown()
        if exists then
            logFH.writeLine( details.name )
        end

        logFH.writeLine( '*' )
        logFH.flush()
        --
        if not tree[info.z] then
            tree[info.z] = {}
        end

        if not tree[info.z][info.round] then
            tree[info.z][info.round] = {}
        end

        if not tree[info.z][info.round][info.direction] then
            tree[info.z][info.round][info.direction] = {}
        end

        tree[info.z][info.round][info.direction].x = info.x
        tree[info.z][info.round][info.direction].y = info.y
    end
}
assert( success, err )

rdaneel:tprint( tree, 2 )
logFH.writeLine( result )
logFH.writeLine( '*' )
logFH.close()
