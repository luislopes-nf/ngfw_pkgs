Ext.ns('Ung');
Ext.ns('Ung.Alpaca');
Ext.ns('Ung.Alpaca.grid');


/**
 * @class Ung.Alpaca.EditorGridPanel
 * @extends Ext.grid.EditorGridPanel
 * Build out an editable grid panel while specifying as few fields as possible.
 * @param {Object} config Configuration options
 */
Ung.Alpaca.EditorGridPanel = Ext.extend( Ext.grid.EditorGridPanel, {
    /* Set this to false for grids that do not need to saved */
    saveData : true,
    enableHdMenu : false,
    enableColumnMove: false,
    changedData : null,
    addedId : 0,

    /**
     * @cfg {Array} recordFields An array of strings containing the fields to create the default 
     * record.  Otherwise, you can define your own record.
     * @cfg {Ext.data.Record} record The record to use for each row.  
     *   This will be created using {@link #recordFields} if one is not specified.
     * @cfg {Ext.data.Store} store to use the read out the data.  This
     *   will be created automatically, if one is not specified.
     * @cfg {Array} entries Data to place into the automatically created {@link #store}.
     */
    constructor : function (config) {
        Ung.Alpaca.Util.updateDefaults( config, {
            width : 620,
            height : 220,
            frame : false,
            iconCls : "icon-grid",
            clicksToEdit : 1,
            stripeRows : true,
            viewConfig : { 
                forceFit : true
            }
        });
        Ung.Alpaca.EditorGridPanel.superclass.constructor.apply( this, arguments );
    },
    initComponent : function()
    {
        this.changedData = {};

        /* Append the selection model to the table */
        if ( this.selectable == true ) {
            var sm = new Ext.grid.CheckboxSelectionModel({
                 listeners : {
                    "selectionchange" : {
                        fn :function(sm) {
                            var deleteButton=Ext.getCmp("delete_button_"+this.getId());
                            if(deleteButton) {
                                sm.getCount()>0?deleteButton.enable():deleteButton.disable()
                            }
                        }.createDelegate(this)
                    }
                 }
             });
            this.columns = [sm].concat( this.columns );
            this.sm = sm;
        }

        this.buildToolbar( this );
        if (this.hasEdit) {
            var editColumn = new Ung.Alpaca.grid.EditColumn({});
            if (!this.plugins) {
                this.plugins = [];
            }
            this.plugins.push(editColumn);
            this.columns.push(editColumn);
        }

        /* Build a record. */
        if ( this.record == null && Ext.isArray( this.recordFields )) {
            var fields = [];
            for ( var c = 0 ; c < this.recordFields.length ; c++ ) {
                var field = this.recordFields[c];
                fields[c] = { name : field, mapping : field };
            }

            this.record = Ext.data.Record.create( fields );
        } else {
            this.record = this.record;
        }

        /* Now build a store */
        if (( this.store == null ) && ( this.record != null )) {
            if ( !this.entries ) {
                this.entries = this.settings[this.name];
            }
            this.store = new Ext.data.Store({
                proxy : new Ext.data.MemoryProxy( this.entries ),
                reader : new Ext.data.ArrayReader( {}, this.record ),
                listeners : {
                    "update" : {
                        fn : function(store, record, operation) {
                            this.updateChangedData(record, "modified");
                        }.createDelegate(this)
                    }
                }                
            });
        }

        Ung.Alpaca.EditorGridPanel.superclass.initComponent.apply( this, arguments );

        /* Untangle Alapca Grid type. */
        this.editorGridPanel = true;
    },
    afterRender : function() {
        Ung.Alpaca.EditorGridPanel.superclass.afterRender.call(this);
        this.getView().getRowClass = function(record, index, rowParams, store) {
            var id = record.get("id");
            if (id < 0) {
                return "grid-row-added";
            } else {
                var d = this.grid.changedData[id];
                if (d) {
                    if (d.op == "deleted") {
                        return "grid-row-deleted";
                    } else {
                        return "grid-row-modified";
                    }
                }
            }
            return "";
        }
    },

    buildToolbar : function( config )
    {
        if ( config.tbar ) {
            for ( var c = 0; c < config.tbar.length ; c++ ) {
                if ( config.tbar[c] == Ung.Alpaca.EditorGridPanel.AddButtonMarker ) {
                    config.tbar[c] = this.addButton();
                } else if ( config.tbar[c] == Ung.Alpaca.EditorGridPanel.DeleteButtonMarker ) {
                    config.tbar[c] = this.deleteButton();
                }
            }
        } else  {
            config.tbar = [ this.addButton(), this.deleteButton() ];
        }

        if ( config.tbar.length == 0 ) {
            config.tbar = null;
        }
    },
    
    addButton : function()
    {
        return {
            text : "Add",
            handler : this.addEntry,
            scope : this
        };
    },
    
    deleteButton : function( )
    {
        return {
            id: "delete_button_"+this.getId(),
            text : "Delete",
            handler : this.deleteSelectedEntries,
            disabled: true,
            scope : this
        };
    },
    
    addEntry : function()
    {
        var entry = new this.record( Ext.decode(Ext.encode(this.recordDefaults)) );
        entry.set("id", this.genAddedId());
        this.stopEditing();
        this.store.insert( 0, entry );
        this.startEditing( 0, 0 );
        application.onFieldChange();
        this.updateChangedData(entry, "added");
    },
    genAddedId : function() {
        this.addedId--;
        return this.addedId;
    },

    updateFieldValue : function( settings )
    {
        if ( this.name == null || this.saveData == false ) {
            return;
        }

        var data = [];
        var entries = this.store.getRange();
        
        for ( var c = 0 ; c < entries.length ; c++ ) {
            var cd=this.changedData[entries[c].get("id")];
            if(cd==null || "deleted" != cd.op) {
                data[c] = entries[c].data;
            }
        }

        settings[this.name] = data;
    },
    
    deleteSelectedEntries : function()
    {
        this.stopEditing();
        application.onFieldChange();
        var sm=this.getSelectionModel();
        var selRecs=sm.getSelections();
        for(var i=selRecs.length-1;i>=0;i--) {
            //this.store.remove(selRecs[i]);
            this.updateChangedData(selRecs[i], "deleted");
        }
        sm.clearSelections();
        if ( Ext.fly(this.getView().getHeaderCell(0)).first().hasClass('x-grid3-hd-checker-on')){
            Ext.fly(this.getView().getHeaderCell(0)).first().removeClass('x-grid3-hd-checker-on');
        }         
    },
    editEntry: function(entry) {
        this.stopEditing();
        /*
        // populate row editor
        this.rowEditor.populate(entry);
        this.rowEditor.show();
        */
    },
    isDirty : function() {
        // Test if there are changed data
        return Ung.Alpaca.Util.hasData(this.changedData);
    },
    // Update Changed data after an operation (modifyed, deleted, added)
    updateChangedData : function(record, currentOp) {
        if (!this.isDirty()) {
            var cmConfig = this.getColumnModel().config;
            for (i in cmConfig) {
                cmConfig[i].sortable = false;
            }
        }
        var id = record.get("id");
        var cd = this.changedData[id];
        if (cd == null) {
            this.changedData[id] = {
                op : currentOp,
                recData : record.data
            };
            if ("deleted" == currentOp) {
                var index = this.store.indexOf(record);
                this.getView().refreshRow(record);
            }
        } else {
            if ("deleted" == currentOp) {
                if ("added" == cd.op) {
                    this.store.remove(record);
                    this.changedData[id] = null;
                    delete this.changedData[id];
                } else {
                    this.changedData[id] = {
                        op : currentOp,
                        recData : record.data
                    };
                    this.getView().refreshRow(record);
                }
            } else {
                if ("added" == cd.op) {
                    this.changedData[id].recData = record.data;
                } else {
                    this.changedData[id] = {
                        op : currentOp,
                        recData : record.data
                    };
                }
            }
        }

    }
});

Ung.Alpaca.EditorGridPanel.AddButtonMarker = {};
Ung.Alpaca.EditorGridPanel.DeleteButtonMarker = {};

// Grid check column
Ung.Alpaca.grid.CheckColumn = Ext.extend(Object, {
    invert: false,
    constructor : function(config) {
        Ext.apply(this, config);
        if (!this.id) {
            this.id = Ext.id();
        }
        if (!this.width) {
            this.width = 55;
        }
        this.renderer = this.renderer.createDelegate(this);
    },
    init : function(grid) {
        this.grid = grid;
        this.grid.on('render', function() {
            var view = this.grid.getView();
            view.mainBody.on('mousedown', this.onMouseDown, this);
        }, this);
    },
    changeRecord : function(record) {
        record.set(this.dataIndex, !record.data[this.dataIndex]);
    },
    onMouseDown : function(e, t) {
        if (t.className && t.className.indexOf('x-grid3-cc-' + this.id) != -1) {
            e.stopEvent();
            var index = this.grid.getView().findRowIndex(t);
            var record = this.grid.store.getAt(index);
            var value = record.get( this.dataIndex );
            this.changeRecord(record);

            /* Everything is legit except for the column index. */
            this.grid.fireEvent( "afteredit", {
                grid : this.grid,
                record : record,
                field : this.name,
                value : value,
                originalValue : !value,
                row : index,
                column : -1
            });
        }
    },
        
    renderer : function(value, metadata, record) {
        metadata.css += ' x-grid3-check-col-td';
        return '<div class="x-grid3-check-col' + ((this.invert?!value:value) ? '-on' : '') + ' x-grid3-cc-' + this.id + '">&#160;</div>';
    }
});

Ung.Alpaca.grid.IconColumn = Ext.extend(Object, {
    constructor : function(config) {
        Ext.apply(this, config);
        if (!this.id) {
            this.id = Ext.id();
        }
        if (!this.width) {
            this.width = 50;
        }
        if (this.fixed == null) {
            this.fixed = true;
        }
        if (this.sortable == null) {
            this.sortable = false;
        }
        if (!this.dataIndex) {
            this.dataIndex = null;
        }
        this.renderer = this.renderer.createDelegate(this);
    },
    init : function(grid) {
        this.grid = grid;
        this.grid.on('render', function() {
            var view = this.grid.getView();
            view.mainBody.on('mousedown', this.onMouseDown, this);
        }, this);
    },

    onMouseDown : function(e, t) {
        if (t.className && t.className.indexOf(this.iconClass) != -1) {
            e.stopEvent();
            var index = this.grid.getView().findRowIndex(t);
            var record = this.grid.store.getAt(index);
            this.handle(record, index)
        }
    },

    renderer : function(value, metadata, record) {
        return '<div class="'+this.iconClass+'">&nbsp;</div>';
    }
});
// Grid edit column
Ung.Alpaca.grid.EditColumn=Ext.extend(Ung.Alpaca.grid.IconColumn, {
    constructor : function(config) {
        if (!config.header) {
            config.header = "Edit";
        }
        if (!config.width) {
            config.width = 50;
        }
        Ung.Alpaca.grid.EditColumn.superclass.constructor.call(this,config);
    },
    iconClass: 'icon-edit-row',
    handle : function(record) {
        this.grid.editEntry(record);
    }
});
