Tableify = require('tableify')
require('tablesorter')

module.exports =
class Renderer
    constructor: (@net, @parent, @table) ->
        @iconify = false
        @layoutDirection = 'tb'
        @generateGraph()
        @renderTable() 

    setupGraph: ->
        @graph = new dagreD3.graphlib.Graph()
        @graph.setDefaultEdgeLabel ( -> {} )
        @graph.setGraph
            rankdir: @layoutDirection
            ranksep: 20, # Vertical node separation
            nodesep: 10, # Horizontal node separation
            edgesep: 20, # Horizontal edge separation
            marginx:  0, # Horizontal graph margin
            marginy:  0  # Vertical graph margin

    generateGraph: ->
        @setupGraph()
        nodes = @net.sortTopologically()
        for node in nodes
            if node.isInGraph
                continue
            layers = [node].concat node.coalesce
            if layers.length>1
                # Rewire the node following the last coalesced node to this one
                lastCoalesed = layers[layers.length-1]
                for child in lastCoalesed.children
                    uberParents = _.clone child.parents
                    uberParents[uberParents.indexOf lastCoalesed] = node
                    child.parents = uberParents
            @insertNode layers

            for parent in node.parents
                @insertLink parent, node
        for source in @graph.sources()
            (@graph.node source).class = 'node-type-source'
        for sink in @graph.sinks()
            (@graph.node sink).class = 'node-type-sink'
        @render()
        
    generateTable: ->
        entry = {name: 'start'}
        tbl = []
        id = 0
        for n in @net.sortTopologically()
            id++
            entry = {
                ID: id
                name: n.name
                type: n.type
                ch_in: n.analysis.chIn
                dim_in: n.analysis.wIn+'x'+n.analysis.hIn
                ch_out: n.analysis.chOut
                dim_out: n.analysis.wOut+'x'+n.analysis.hOut
                ops_raw: n.analysis.comp
                mem_raw: n.analysis.mem
            }                
            tbl.push(entry)
        return tbl
        
    toSuffixForm: (num, decimals = 2) ->
        exponents = [12,  9,  6,  3]
        suffices  = ["T","G","M","k"]
        decimals = Math.pow(10, decimals)
        #debugger
        for exponent,i in exponents
            suffix = suffices[i]
            factor = Math.pow(10, exponent)
            if (num > factor)
                return Math.round(num/factor*decimals)/decimals+suffix
        return num
        
    summarizeTable: (tbl) ->
        entry = {name: 'start'}
        summary = []
        num_subs = 0
        for n in tbl
            slashindex = n.name.indexOf('/')
            if (slashindex>0 and entry.name.substring(0,slashindex) == n.name.substring(0,slashindex))
                num_subs++
                entry.name = n.name.substring(0,slashindex)
                entry.type = 'submodule('+num_subs+')'
                entry.ch_out = n.ch_out
                entry.dim_out = n.dim_out
                entry.ops_raw[key] += n.ops_raw[key] for key of entry.ops_raw               
                entry.mem_raw[key] += n.mem_raw[key] for key of entry.mem_raw
                entry.ops[key] = @toSuffixForm(val) for key,val of entry.ops_raw when val > 0
                entry.mem[key] = @toSuffixForm(val) for key,val of entry.mem_raw when val > 0
                entry.ops
                summary.pop()
                summary.push(entry)
             else
                num_subs = 0
                entry = {
                    ID: n.ID
                    name: n.name
                    type: n.type
                    ch_in: n.ch_in
                    dim_in: n.dim_in
                    ch_out: n.ch_out
                    dim_out: n.dim_out
                    ops_raw: n.ops_raw
                    mem_raw: n.mem_raw
                    ops: {}
                    mem: {}
                }
                entry.ops[key] = @toSuffixForm(val) for key,val of entry.ops_raw when val > 0
                entry.mem[key] = @toSuffixForm(val) for key,val of entry.mem_raw when val > 0
                summary.push(entry)     
        
        # initialize TOTAL row
        total = {name: 'TOTAL', ops_raw: {}, mem_raw: {}, ops: {}, mem: {}}
        _.extend(total.ops_raw, summary[0].ops_raw) # copy zeros from data layer
        _.extend(total.mem_raw, summary[0].mem_raw) # idem
        for entry in summary
            #debugger
            total.ops_raw[key] += entry.ops_raw[key] for key of entry.ops_raw
            total.mem_raw[key] += entry.mem_raw[key] for key of entry.mem_raw          
        total.ops[key] = @toSuffixForm(val) for key,val of total.ops_raw
        total.mem[key] = @toSuffixForm(val) for key,val of total.mem_raw      
        summary.push(total) 
        summary_without_raw = (_.omit(entry, ['ops_raw','mem_raw']) for entry in summary)
        return summary_without_raw
        
    renderTable: ->
        tbl = @generateTable()
        summary = @summarizeTable(tbl)
        $(@table).html('<h3>Summary:</h3>'+Tableify(summary)+
                       '<h3>Details:</h3>'+Tableify(tbl));
        $(@table+' table').tablesorter()
        for row in $(@table+' table tr')
            # click on "Name" -> scroll to node in diagram
            row.children[1].onclick = -> 
                #debugger;
                node = $('div[id^="node-'+this.textContent+'"]')
                center_offset = 200;
                $("body,html").animate(
                    { scrollTop: node.offset().top-center_offset }, 200
                );
                $(node).addClass('node-highlight')
                removeHighlight = (node) -> 
                    return () -> $(node).removeClass('node-highlight')
                window.setTimeout(removeHighlight(node), 4000)

    insertNode: (layers) ->
        baseNode = layers[0]
        nodeClass = 'node-type-'+baseNode.type.replace(/_/g, '-').toLowerCase()
        nodeLabel = ''
        for layer in layers
            layer.isInGraph = true
            nodeLabel += @generateLabel layer
            nodeDesc =
                labelType   : 'html'
                label       : nodeLabel
                class       : nodeClass
                layers      : layers
                rx          : 5
                ry          : 5
        if @iconify
            _.extend nodeDesc,
                shape: 'circle'
        @graph.setNode baseNode.name, nodeDesc

    generateLabel: (layer) ->
        if not @iconify
            '<div class="node-label" id="node-'+layer.name+'">'+layer.name+'</div>'
        else
            ''

    insertLink: (src, dst) ->
        lbl = src.analysis.chOut+'ch ⋅ '+src.analysis.wOut+'×'+src.analysis.hOut                       
        @graph.setEdge(src.name, dst.name, { arrowhead: 'vee', label: lbl } );

    renderKey:(key) ->
        key.replace(/_/g, ' ')

    renderValue: (value) ->
        if Array.isArray value
            return value.join(', ')
        return value

    renderSection: (section) ->
        s = ''
        for own key of section
            val = section[key]
            isSection = (typeof val is 'object') and not Array.isArray(val)
            if isSection
                s += '<div class="node-param-section-title node-param-key">'+@renderKey(key)+'</div>'
                s += '<div class="node-param-section">'
                s+= @renderSection val
            else
                s += '<div class="node-param-row">'
                s += '<span class="node-param-key">'+@renderKey(key)+': </span>'
                s += '<span class="node-param-value">'+@renderValue(val)+'</span>'
            s += '</div>'
        return s

    tipForNode: (nodeKey) ->
        node = @graph.node nodeKey
        s = ''
        for layer in node.layers
            s += '<div class="node-info-group">'
            s += '<div class="node-info-header">'
            s += '<span class="node-info-title">'+layer.name+'</span>'
            s += ' &middot; '
            s += '<span class="node-info-type">'+@renderKey(layer.type)+'</span>'
            if layer.annotation?
                s += ' &middot; <span class="node-info-annotation">'+layer.annotation+'</span>'
            s += '</div>'
            s += @renderSection layer.attribs
        return s

    render: ->
        svg = d3.select(@parent)
        svgGroup = svg.append('g')
        graphRender = new dagreD3.render()
        graphRender svgGroup, @graph

        # Size to fit.
        # getBBox appears to do the right thing on Chrome,
        # but not on Firefox. getBoundingClientRect works on both.
        bbox = svgGroup.node().getBoundingClientRect()
        svg.attr('width', bbox.width)
        svg.attr('height', bbox.height)

        # Configure Tooltips.
        tipPositions =
            tb:
                my: 'left center'
                at: 'right center'
            lr:
                my: 'top center'
                at: 'bottom center'
        that = @
        svgGroup.selectAll("g.node").each (nodeKey) ->
            position = tipPositions[that.layoutDirection]
            position.viewport = $(window)
            $(this).qtip
                content:
                    text: that.tipForNode nodeKey
                position: position
                show:
                    delay: 0
                    effect: false
                hide:
                    effect: false
