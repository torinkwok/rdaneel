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

function rdaneel:_dir2Idx ( direction )
    local idx
    if direction and type( direction ) == 'string' then
        if direction == 'fd' then
            idx = 1
        elseif direction == 'rt' then
            idx = 2
        elseif direction == 'bk' then
            idx = 3
        elseif direction == 'lt' then
            idx = 4
        end
    end
    return idx
end

function rdaneel:_idx2Dir ( index )
    local dir
    if index and type( index ) == 'number' then
        if index == 1 then
            dir = 'fd'
        elseif index == 2 then
            dir = 'rt'
        elseif index == 3 then
            dir = 'bk'
        elseif index == 4 then
            dir = 'lt'
        end
    end
    return dir
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

        io.write( string.format( "Fd: %2d, Rt: %2d, Bk: %2d, Lt: %2d\n",
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

        for direction, nsteps in pairs( paths ) do
            local infoTbl = {
                round = roundIdx, direction = direction,
                nthStep = nil, x = nil, y = nil,
            }
            if nsteps == 0 then
                if sweepCallback then
                    infoTbl.x = x; infoTbl.y = y; infoTbl.nthStep = 0; infoTbl.done = true
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
                        infoTbl.x = x; infoTbl.y = y; infoTbl.nthStep = n
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

--[[ Print contents of `tbl`, with indentation.
    `indent` sets the initial level of indentation.
]]
function rdaneel:tprint ( tbl, indent )
    local buffer = ''
    if not indent then indent = 0 end
    for k, v in pairs( tbl ) do
        formatting = string.rep( "  ", indent ) .. k .. ": "
        if type( v ) == "table" then
            buffer = buffer
                .. formatting .. "\n"
                .. rdaneel:tprint( v, indent + 1 )
        else
            buffer = buffer .. formatting .. v .. "\n"
        end
    end
    return buffer
end

logFH = fs.open( 'log', 'w' )
logFormat = "Round=%d; Dir=%s; nthStep=%d; [X=%d Y=%d Z=%d]; DONE=%s"

local tree = {}
success, err = rdaneel:sweepSolid {
    length = 4, width = 3, height = 4,
    reversed = false,
    sweepCallback = function ( info )
        local exists, details = turtle.inspectDown()
        local direction = rdaneel:_idx2Dir( info.direction )

        -- Logging
        local log = string.format(
            logFormat, 
            info.round, direction, info.nthStep,
            info.x, info.y, info.z,
            info.done and 'true' or 'false' )

        logFH.writeLine( log )

        if exists then logFH.writeLine( details.name ) end
        logFH.writeLine( '*' ); logFH.flush()
        --
        local zTbl
        if not tree[ info.z ] then zTbl = {}; tree[ info.z ] = zTbl else zTbl = tree[ info.z ] end

        local roundTbl
        if not zTbl[ info.round ] then roundTbl = {}; zTbl[ info.round ] = roundTbl else roundTbl = zTbl[ info.round ] end

        local dirTbl
        if not roundTbl[ direction ] then dirTbl = {}; roundTbl[ direction ] = dirTbl else dirTbl = roundTbl[ direction ] end        

        table.insert( dirTbl, #dirTbl + 1, { x = info.x, y = info.y } )
    end
}
assert( success, err )

local result = rdaneel:tprint( tree, 2, result ); logFH.writeLine( result ); logFH.writeLine( '*' )
logFH.close()
