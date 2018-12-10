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

function table.shallow_find ( arr, pred )
    for _, v in ipairs( arr ) do
        if pred( v ) then return v end
    end
    return nil
end

function table.shallow_len ( tbl )
    local count = 0
    for _ in pairs( tbl ) do count = count + 1 end
    return count
end

function table.dump ( tbl, indent )
    local buffer = ''
    if not indent then indent = 0 end
    for k, v in pairs( tbl ) do
        formatting = string.rep( "  ", indent ) .. k .. ": "
        if type( v ) == "table" then
            buffer = buffer
                .. formatting .. "\n"
                .. table.dump( v, indent + 1 )
        else
            buffer = buffer .. formatting .. tostring( v ) .. "\n"
        end
    end
    return buffer
end

--[[
    ON FAILURE: Returns an error message.
]]
function bpsave ( tbl, filename )
    local _exportstring = function ( s )
        return string.format( "%q", s )
    end

    local cs, ce = '   ', "\n"
    local fh = io.open( filename, 'w' )

    if not fh then
        return "Failed to open " .. filename .. " to write"
    end

    -- initiate variables for save procedure
    local tables, lookup = { tbl }, { [tbl] = 1 }
    fh:write( "return {" .. ce )

    for idx, t in ipairs( tables ) do
        fh:write( "-- Table: {" .. idx .. '}' .. ce )
        fh:write( '{' .. ce )

        local thandled = {}

        for i, v in ipairs( t ) do
            thandled[i] = true

            local stype = type( v )

            -- only handle value
            if stype == "table" then
                if not lookup[v] then
                    table.insert( tables, v )
                    lookup[v] = #tables
                end
                fh:write( cs .. '{' .. lookup[v] .. '},' .. ce )

            elseif stype == "string" then
                fh:write(  cs .. _exportstring( v ) .. ',' .. ce )

            elseif stype == "number" or stype == "boolean" then
                fh:write(  cs .. tostring( v ) .. ',' .. ce )
            end
        end

        for i, v in pairs( t ) do

            -- escape handled values
            if not thandled[i] then
                local str = ''
                local stype = type( i )

                -- handle index
                if stype == "table" then
                    if not lookup[i] then
                        table.insert( tables, i )
                        lookup[i] = #tables
                    end
                    str = cs .. "[{" .. lookup[i] .. "}]="

                elseif stype == "string" then
                    str = cs .. '[' .. _exportstring( i ) .. "]="

                elseif stype == "number" or stype == "boolean" then
                    str = cs .. '[' .. tostring( i ) .. "]="
                end
                
                if str ~= '' then
                    stype = type( v )
                    -- handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert( tables, v )
                            lookup[v] = #tables
                        end
                        fh:write( str .. '{' .. lookup[v] .. '},' .. ce )

                    elseif stype == "string" then
                        fh:write( str .. _exportstring( v ) .. ',' .. ce )

                    elseif stype == "number" or stype == "boolean" then
                        fh:write( str .. tostring( v ) .. ',' .. ce )
                    end
                end
            end
        end
        fh:write( '},' .. ce )
    end
    fh:write( '}' )
    fh:close()
end

--[[
    ON SUCCESS: Returns a previously saved blueprint.
    ON FAILURE: Returns as second argument an error message.
]]
function bpload ( sfile )
    local ftables, err = loadfile( sfile )
    if err then return _, err end

    local tables = ftables()
    for idx = 1, #tables do
        local tolinki = {}
        for i, v in pairs( tables[idx] ) do
            if type( v ) == "table" then
                tables[idx][i] = tables[ v[1] ]
            end
            if type( i ) == "table" and tables[ i[1] ] then
                table.insert( tolinki, { i, tables[ i[1] ] } )
            end
        end
        -- link indices
        for _, v in ipairs( tolinki ) do
            tables[idx][ v[2] ], tables[idx][ v[1] ] = tables[idx][ v[1] ], nil
        end
    end
    return tables[1]
end

function turtle:goup ( destroy ) if self and turtle.detectUp() then turtle.digUp() end turtle.up() end
function turtle:godn ( destroy ) if self and turtle.detectDown() then turtle.digDown() end turtle.down() end
function turtle:gofd ( destroy ) if self and turtle.detect() then turtle.dig() end turtle.forward() end

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

function turtle.go_back_origin ( x, y, direction )
    if direction == 1 then rdaneel:turtleTurnRight( 2 ) end
    if direction == 2 then rdaneel:turtleTurnRight()    end
    if direction == 4 then rdaneel:turtleTurnLeft()     end

    rdaneel:turtleGoForward( y + 1, true )
    rdaneel:turtleTurnRight()
    rdaneel:turtleGoForward( x, true )
    rdaneel:turtleTurnRight()
end

local G_DIRECTIONS = { 'fd', 'rt', 'bk', 'lt' }

local function dir2idx ( direction )
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

local function idx2dir ( index )
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

local function fac2idx ( facing )
    local idx
    if facing and type( facing ) == 'string' then
        if facing == 'north' then
            idx = 1
        elseif facing == 'east' then
            idx = 2
        elseif facing == 'south' then
            idx = 3
        elseif facing == 'west' then
            idx = 4
        end
    end
    return idx
end

local function idx2fac ( index )
    local fac
    if index and type( index ) == 'number' then
        if index == 1 then
            fac = 'north'
        elseif index == 2 then
            fac = 'east'
        elseif index == 3 then
            fac = 'south'
        elseif index == 4 then
            fac = 'west'
        end
    end
    return fac
end

local NAMEID_VARIANTS = {
    ['minecraft:redstone'] = { 'minecraft:redstone_wire' },
    ['minecraft:repeater'] = { 'minecraft:powered_repeater', 'minecraft:unpowered_repeater' },
    ['minecraft:comparator'] = { 'minecraft:powered_comparator', 'minecraft:unpowered_comparator' },
    ['minecraft:redstone_torch'] = { 'minecraft:unlit_redstone_torch' },
    ['minecraft:redstone_lamp'] = { 'minecraft:lit_redstone_lamp' },
}

local function nameid_lookup ( id )
    for std, variants in pairs( NAMEID_VARIANTS ) do
        if table.shallow_find( variants, function ( v ) return id == v end ) then
            return std
        end
    end
    return id
end

-- turtle.select_empty_slot selects inventory slot that is empty,
-- returns `true` if found, `false` if no empty spaces

function turtle.select_empty_slot()
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

-- turtle.count_inventory() returns the total number of items in
-- the inventory

function turtle.count_inventory ()
    local total = 0

    for slot = 1, rdaneel._constants.slotsNum do
        total = total + turtle.getItemCount( slot )
    end

    return total
end

-- turtle.select_and_placedown() selects a nonempty slot and
-- places a block from it under the turtle

function turtle.select_and_placedown ( destroy )
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

function num_of_rounds ( length, width )
    return math.ceil( math.min( length, width ) / 2 )
end

function coordinate_calculus ( flat_len, flat_wid, x, y )
    local h = math.ceil( flat_wid / 2 )
    local v = math.ceil( flat_len / 2 )

    local maxx, maxy = flat_len - 1, flat_wid - 1

    local r = math.min( x >= v and v - ( x - ( maxx - v ) ) or x,
                        y >= h and h - ( y - ( maxy - h ) ) or y )

    local d, n
    local delta = r
    local tp = 1 -- number of block occupied by a turning point

    if x == delta and y <= maxy - delta then
        d = 'fd'
        n = ( y + 1 ) - delta
    elseif x == maxx - delta and y <= maxy - ( delta + tp ) then
        d = 'bk'
        n = ( maxy - y + 1 ) - ( delta + tp )
    elseif x >= delta + tp then
        if x <= maxx - delta and y == maxy - delta then
            d = 'rt'
            n = x + 1 - ( delta + tp )
        elseif x <= maxx - delta - 1 and y == delta then
            d = 'lt'
            n = ( maxx - x + 1 ) - ( delta + tp )
        end
    end

    return { round = r, direction = d, nth_step = n }
end

-- local result = coordinate_calculus( 11, 11, 10, 6 )
-- print( result.round, result.direction, result.nth_step )

function turtle.sweep_flat ( length, width, sweepCallback )

    local minimum = length * width
    if turtle.getFuelLevel() < minimum then
        return false, 'HAVE NO ENOUGH FUEL'
    end

    -- Yes, we count the number of rounds from zero
    for ri = 0, num_of_rounds( length, width ) - 1 do
    
        local paths = nil

        local evenDelta = ri * 2
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

        local x = ri
        local y = ri - 1

        for direction, nsteps in pairs( paths ) do
            local ctx_tbl = {
                round = ri, direction = direction,
                nthStep = nil, x = nil, y = nil,
            }
            if nsteps == 0 then
                if sweepCallback then
                    ctx_tbl.x = x; ctx_tbl.y = y; ctx_tbl.nthStep = 0; ctx_tbl.done = true
                    sweepCallback( ctx_tbl )
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
                        ctx_tbl.x = x; ctx_tbl.y = y; ctx_tbl.nthStep = n
                        sweepCallback( ctx_tbl )
                    end
                end
                turtle.turnRight()
            end
        end
        if done then
            break
        end
    end
    return true
end

function turtle.sweep_solid ( args )

    local length, width = args.length, args.width
    assert( length and width, 'Length and width must be specified' )

    local height = args.height or 1
    local reversed = args.reversed or false
    local f = args.sweepCallback

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
        local success, err = turtle.sweep_flat(
            length, width,
            function ( ctx )
                ctx.z = z;
                if f then
                    assert( type( f ) == 'function', 'Callback is required to be a function' ) 
                    f( ctx )
                end
                if ctx.done then
                    turtle.go_back_origin( ctx.x, ctx.y, ctx.direction )
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

--[[ POSIX style command line argument parser.

    PARAM `args` contains the command line arguments in a standard table.
    PARAM `options` is a string with the letters that expect string values.

    Returns a table where associated keys are true, nil, or a string value.

    The following example styles are supported:

    -a one  ==> opts['a'] == 'one'
    -bone   ==> opts['b'] == 'one'
    -c      ==> opts['c'] == true
    --c=one ==> opts['c'] == 'one'
    -cdaone ==> opts['c'] == true; opts['d'] == true; opts['a'] == 'one'

    NOTE: POSIX demands the parser ends at the first non option
    this behavior isn't implemented.
]]
function posix_getopt ( args, options )
    local opts = {}

    for k, v in ipairs( args ) do
        if string.sub( v, 1, 2 ) == "--" then
            local x = string.find( v, '=', 1, true )
            if x then
                opts[ string.sub( v, 3, x - 1 ) ] = string.sub( v, x + 1 )
            else
                opts[ string.sub( v, 3 ) ] = true
            end

        elseif string.sub( v, 1, 1 ) == '-' then
            local y = 2
            local l = string.len( v )
            local jopt

            while ( y <= l ) do
                jopt = string.sub( v, y, y )
                if string.find( options, jopt, 1, true ) then
                    if y < l then
                        opts[ jopt ] = string.sub( v, y + 1 )
                        y = l
                    else
                        opts[ jopt ] = args[ k + 1 ]
                    end
                else
                    opts[ jopt ] = true
                end
                y = y + 1
            end
        end
    end
    return opts
end

---8<---

-- draft

function draft ( args )
    local logfh, logformat

    if args.g then
        logfh = fs.open( 'rdaneel.draft.log', 'w' )
        logformat = "Round=%d; Dir=%s; nthStep=%d; [X=%d Y=%d Z=%d]; DONE=%s"
    end

    local tree = {}
    local success, err = turtle.sweep_solid {
        length = args.l, width = args.w, height = args.h,
        reversed = true,
        sweepCallback = function ( ctx )
            local exists, details = turtle.inspectDown()
            if exists then
                details.name = nameid_lookup( details.name )
            else
                details = {}
            end

            local direction = idx2dir( ctx.direction )

            -- Logging
            if logfh then
                local log = string.format(
                    logformat, 
                    ctx.round, direction, ctx.nthStep,
                    ctx.x, ctx.y, ctx.z,
                    ctx.done and 'true' or 'false' )

                logfh.writeLine( log )

                if exists then logfh.writeLine( details.name ) end
                logfh.writeLine( '*' ); logfh.flush()
            end
            --
            local zTbl
            if not tree[ ctx.z ] then zTbl = {}; tree[ ctx.z ] = zTbl else zTbl = tree[ ctx.z ] end

            local roundTbl
            if not zTbl[ ctx.round ] then roundTbl = {}; zTbl[ ctx.round ] = roundTbl else roundTbl = zTbl[ ctx.round ] end

            local dirTbl
            if not roundTbl[ direction ] then dirTbl = {}; roundTbl[ direction ] = dirTbl else dirTbl = roundTbl[ direction ] end        

            table.insert( dirTbl, #dirTbl + 1,
                          { x = ctx.x, y = ctx.y, block = details, } )
        end
    }; assert( success, err )

    local err_msg = bpsave( tree, args.o )
    if err_msg ~= nil then
        error( err_msg )
    end

    if logfh then
        logfh.writeLine( table.dump( tree ) )
        logfh.close()
    end
end

-- craft

function BOILERPLATE ()
    local destroyed, destroyed_block = turtle.inspectDown()

    rdaneel:turtleGoDown( 1, true )
    turtle.place()
    rdaneel:turtleGoUp( 1, true )

    if destroyed then
        if turtle.select_item( nameid_lookup( destroyed_block.name ) ) then
            turtle.placeDown()
        end
    end
end

function type_of_intersection ( dparams )
    local td, bd = dparams.td, dparams.bd -- turtle direction vs. block direction

    assert( td and bd
            and table.shallow_find( G_DIRECTIONS, function ( v ) return v == td end )
            and table.shallow_find( G_DIRECTIONS, function ( v ) return v == bd end ),
            "Bad arguments" )

    if td == bd then
        return 1

    elseif ( td == 'fd' and bd == 'bk' ) or ( td == 'bk' and bd == 'fd' )
        or ( td == 'lt' and bd == 'rt' ) or ( td == 'rt' and bd == 'lt' )
    then
        return 2

    elseif ( td == 'fd' and bd == 'lt' ) or ( td == 'bk' and bd == 'rt' )
        or ( td == 'rt' and bd == 'fd' ) or ( td == 'lt' and bd == 'bk' )
    then
        return 3

    elseif ( td == 'fd' and bd == 'rt' ) or ( td == 'bk' and bd == 'lt' )
        or ( td == 'rt' and bd == 'bk' ) or ( td == 'lt' and bd == 'fd' )
    then
        return 4
    end
end

function craft ( args )
    local logfh
    if args.g then
        logfh = fs.open( 'rdaneel.craft.log', 'w' )
    end

    local bptbl, err_msg = bpload( args.i )
    assert( bptbl, err_msg )

    local rt_steps, fd_steps = bptbl[0][0].rt, bptbl[0][0].fd

    local l = rt_steps[ #rt_steps ].x + 1
    local w = fd_steps[ #fd_steps ].y + 1
    local h = #bptbl + 1

    local turtel_facing = turtle.figure_facing()

    local dir2fac_lookup = {}
    for i = 1, 4 do dir2fac_lookup[ idx2dir( i ) ] = turtle.rotate_facing( turtel_facing, i - 1 ) end

    local fac2dir_lookup = {}
    for k, v in pairs( dir2fac_lookup ) do fac2dir_lookup[v] = k end

    local preinstalled_blocks = {}

    turtle.sweep_solid {
        length = l, width = w, height = h,
        reversed = false,
        sweepCallback = function ( ctx )

            local x, y, z = ctx.x, ctx.y, ctx.z

            if table.shallow_find(
                preinstalled_blocks,
                function ( v ) return v[1] == x and v[2] == y and v[3] == z end )
            then
                return
            end

            local r = ctx.round
            local di = ctx.direction
            local d = idx2dir( di )
            local n = ctx.nthStep > 0 and ctx.nthStep or 1

            local b = bptbl[z][r][d][n].block
            if table.shallow_len( b ) == 0 then -- if the block is not empty
                return
            end

            local place_f = turtle.placeDown
            local bfac = b.state.facing
            local bdir = fac2dir_lookup[ bfac ]

            if bfac and not ( bfac == 'up' or bfac == 'down' ) then
                local is_attachable =
                    b.name == 'minecraft:redstone_torch'
                    or b.name == 'minecraft:torch'
                    or b.name == 'minecraft:lever'

                local t = type_of_intersection { td = d, bd = bdir }

                if t == 1 then
                    place_f = function ()
                        rdaneel:turtleGoForward( 1, true )
                        rdaneel:turtleTurnRight( 2 )
                        rdaneel:turtleGoDown( 1, true )

                        turtle.place()

                        rdaneel:turtleGoUp( 1, true )
                        rdaneel:turtleGoForward( 1, true )
                        rdaneel:turtleTurnRight( 2 )

                        return true
                    end

                elseif is_attachable and t == 2 then
                    place_f = function ()
                        local base_block_x, base_block_y = x, y

                        if bdir == 'fd' then
                            base_block_y = y - 1
                        elseif bdir == 'bk' then
                            base_block_y = y + 1
                        elseif bdir == 'lt' then
                            base_block_x = x + 1
                        elseif bdir == 'rt' then
                            base_block_x = x - 1
                        end

                        local res = coordinate_calculus( l, w, base_block_x, base_block_y )
                        local base_block = bptbl[z][res.round][res.direction][res.nth_step].block                        

                        rdaneel:turtleGoForward( 1, true )

                        local slot = turtle.seek_item( base_block.name )
                        assert( slot, "Failed finding out " .. base_block.name )
                        turtle.select_and_place { slot = slot, down = true, destroy = true }
                        table.insert( preinstalled_blocks, { base_block_x, base_block_y, z } )

                        turtle.select_item( b.name )

                        rdaneel:turtleTurnRight( 2 )
                        rdaneel:turtleGoForward( 2, true )
                        rdaneel:turtleTurnRight( 2 )

                        BOILERPLATE()

                        rdaneel:turtleGoForward( 1, true )
                        return true
                    end

                elseif is_attachable and t == 3 then
                    place_f = function ()
                        local base_block_x, base_block_y = x, y

                        if bdir == 'fd' then
                            base_block_y = y - 1
                        elseif bdir == 'bk' then
                            base_block_y = y + 1
                        elseif bdir == 'lt' then
                            base_block_x = x + 1
                        elseif bdir == 'rt' then
                            base_block_x = x - 1
                        end

                        local res = coordinate_calculus( l, w, base_block_x, base_block_y )
                        local base_block = bptbl[z][res.round][res.direction][res.nth_step].block

                        rdaneel:turtleTurnRight( 1 )
                        rdaneel:turtleGoForward( 1, true )

                        local slot = turtle.seek_item( base_block.name )
                        assert( slot, "Failed finding out " .. base_block.name )
                        turtle.select_and_place { slot = slot, down = true, destroy = true }
                        table.insert( preinstalled_blocks, { base_block_x, base_block_y, z } )

                        turtle.select_item( b.name )

                        rdaneel:turtleTurnRight( 2 )
                        rdaneel:turtleGoForward( 2, true )
                        rdaneel:turtleTurnRight( 2 )

                        BOILERPLATE()

                        rdaneel:turtleGoForward( 1, true )
                        rdaneel:turtleTurnLeft( 1 )

                        logfh.writeLine( table.dump( res ) )
                        logfh.writeLine( table.dump( base_block ) )
                        logfh.writeLine(
                            string.format( "[%d %d %d] BID=%s BFAC=%s BDIR=%s CUR_DIR=%s\n"
                                               .. "[%d %d] BASE_ID=%s\n"
                                               .. "\n---\n",
                                           x, y, z, b.name, bfac, bdir, d,
                                           base_block_x, base_block_y, base_block.name ) );
                        logfh.flush()
                        return true
                    end

                elseif is_attachable and t == 4 then
                    place_f = function ()
                        rdaneel:turtleTurnRight( 1 )
                        rdaneel:turtleGoForward( 1, true )
                        rdaneel:turtleTurnRight( 2 )

                        BOILERPLATE()

                        rdaneel:turtleGoForward( 1, true )
                        rdaneel:turtleTurnRight( 1 )

                        return true
                    end
                end
            end
            if turtle.select_item( b.name ) then
                place_f()
            end
        end
    }

    if logfh then
        logfh.close()
    end
end

local G_COMPASS_BLOCKS = {
    'minecraft:torch',
    'minecraft:redstone_torch',
    'minecraft:ladder',
    'minecraft:lever',
}

local G_COMPASS_BASE_BLOCKS = {
    'minecraft:log',
    'minecraft:log2',
    'minecraft:log3',
    'minecraft:log4',
}

local function is_table_of_type ( tbl, t )
    if not ( tbl and t ) then
        return false
    end

    -- If tbl is empty,
    -- it is considered as a table of any type

    for _, v in ipairs( tbl ) do
        if type( v ) ~= t then
            return false
        end
    end

    return true
end

function turtle.seek_item ( arg )
    local names =
        type( arg ) == 'string' and { arg } or ( type( arg ) == 'table' and arg or nil )

    assert( is_table_of_type( names, 'string' ),
            'Bad argument: arg must be either a string or a table of string' )

    local curslot = turtle.getSelectedSlot()
    local curslot_detail = turtle.getItemDetail( curslot )

    for _, name in ipairs( names ) do
        if curslot_detail and curslot_detail.name == name then
            return curslot
        end

        -- check all inventory slots except for current slot

        for slot = 1, rdaneel._constants.slotsNum do
            if slot ~= curslot then
                local item = turtle.getItemDetail( slot )
                if item and item.name == name then
                    return slot
                end
            end
        end
    end

    return nil -- couldn't find item
end

-- turtle.select_item() selects the inventory slot with the names
-- item, returns the slot index if found and nil if not

function turtle.select_item ( arg )
    local slot_idx = turtle.seek_item( arg )
    if slot_idx then
        return turtle.select( slot_idx ) and slot_idx or nil
    end
    return nil
end

function turtle.select_and_place ( args )
    function _fvars ( up, down )
        -- UP and DOWN must not be specified simultaneously
        assert( not( up and down ), 'Conflict placing direction' )

        if up then
            return turtle.detectUp, turtle.digUp, turtle.placeUp, turtle.inspectUp
        elseif down then
            return turtle.detectDown, turtle.digDown, turtle.placeDown, turtle.inspectDown
        else
            return turtle.detect, turtle.dig, turtle.place, turtle.inspect
        end
    end

    local detect_f, dig_f, place_f, inspect_f = _fvars( args.up, args.down )

    local slot = args.slot or turtle.getSelectedSlot()
    if turtle.getItemCount( slot ) == 0 then
        return false, 'Slot ' .. tostring( slot ) .. ' is empty'
    end

    if not turtle.select( slot ) then
        return false, 'Failed selecting specified slot ' .. tostring( slot )
    end

    local destroy = args.destroy
    if detect_f() then
        if destroy then
            dig_f()
        else
            local exists, details = inspect_f()
            return false, 'Irrelevant block ' .. ( exists and details.name .. ' ' or '' ) .. 'stands in the way'
        end
    end

    -- If the invoker didn't pass a slot, place_f() will pick
    -- block from current selected slot

    return place_f()
end

function turtle.figure_facing ( keeping )

    local compass_slot = turtle.select_item( G_COMPASS_BLOCKS )
    assert( compass_slot, "Failed obtaining a block used for figuring the facing out" )

    local base_slot = turtle.select_item( G_COMPASS_BASE_BLOCKS )
    assert( base_slot, "Failed obtaining a base block for the compass block" )

    rdaneel:turtleTurnRight( 2 )
    rdaneel:turtleGoForward( 1, true )

    local success, err_msg = turtle.select_and_place { slot = base_slot, destroy = true }
    if not success then
        return nil, err_msg
    end

    turtle.back()
    turtle.select_and_place { slot = compass_slot, destroy = true }

    local exists, compass_details = turtle.inspect()
    assert( exists, 'Compass damaged' )

    if not keeping then
        rdaneel:turtleGoForward( 1, true ); turtle.dig()
        turtle.back()
    end
    rdaneel:turtleTurnLeft( 2 )

    return compass_details.state.facing
end

function turtle.rotate_facing ( fac, times )
    local i = fac2idx( fac )
    for _ = 1, times or 1 do i = i % 4 + 1 end
    return idx2fac( i )
end

do
    local cli_args = {...}
    local verb = table.remove( cli_args, 1 )

    if verb == 'draft' then
        local opts = posix_getopt( cli_args, 'lwhog' ) -- TODO: To process -g flag

        assert( opts.h and opts.w and opts.h, "Length [-l], width [-w] and height [-h] must all be specified correctly" )
        assert( opts.o and #opts.o > 0, "Output file [-o] must be specified correctly" )

        local l, w, h = tonumber( opts.l ), tonumber( opts.w ), tonumber( opts.h )
        local o = opts.o

        assert( type( l ) == 'number' and type( w ) == 'number' and type( h ) == 'number',
                "Length, width, and height must all be numbers" )

        draft { l = l,
                w = w,
                h = h,
                o = o,
                g = true }

        -- turtle.sweep_flat( l, w )

    elseif verb == 'craft' then
        local opts = posix_getopt( cli_args, 'ig' ) -- TODO: To process -g flag
        assert( opts.i and #opts.i > 0, "Input file [-i] must be specified correctly" )

        local i = opts.i
        craft { i = i, g = true }
    else
        print( "Usages:\n"
                   .. "\trdaneel draft -l4 -w3 -l3 -o output\n"
                   .. "\trdaneel craft --i=input -g" )
        return false
    end
    return true
end
