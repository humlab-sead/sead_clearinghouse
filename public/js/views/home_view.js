window.HomeView = Backbone.View.extend({

    selected_submission_id: 0,
    submissions: null,
    
    initialize: function (options) {
        this.options = options || {};
        this.submissions = this.options.items;
        this.render();
    },

    events: {
        'click #button-open-submission': 'open',
        'click #button-claim-submission': 'claim',
        'click #button-unclaim-submission': 'unclaim',
        'click #button-transfer-submission': 'transfer',
    },
    
    reset_status: function()
    {
        this.selected_submission_id = 0;
        utils.set_disabled_state(this.$open_button, true);
        utils.set_disabled_state(this.$claim_button, true);
        utils.set_disabled_state(this.$unclaim_button, true);
        utils.set_disabled_state(this.$transfer_button, true);
    },

    render: function () {

        $(this.el).html(this.template());
        
        this.tableView = new SubmissionListView({ submissions: this.submissions });
        
        this.listenTo(this.tableView, "submission-selected", this.submissionSelected);
        this.listenTo(this.tableView, "submission-deselected", this.submissionDeselected);
        this.listenTo(this.tableView, "paging-occurred", this.reset_status);
        
        $('#submission_list_container', this.el).html(this.tableView.render().el);
        
        $(this.el).find("div.toolbar").html(TemplateStore.get("template_submission_list_toolbar")());

        this.$show_users_button = $("#open-users-button");
        this.$open_button = $("#button-open-submission", this.$el);
        this.$claim_button = $("#button-claim-submission", this.$el);
        this.$unclaim_button = $("#button-unclaim-submission", this.$el);
        this.$transfer_button = $("#button-transfer-submission", this.$el);

        this.$show_users_button.toggle(SEAD.Security.has_edit_user_privilage);
        
        $("#latest_sites_container", this.$el).html(new LatestSitesView().el);
        $("#documentation_container", this.$el).html(new DocumentationListView().el);

        this.reset_status();
 
        return this;
    },

    submissionSelected: function(id, index)
    {
        this.selected_submission_id = id;
        var submission = this.submissions.at(index);
        utils.set_disabled_state(this.$open_button, !SEAD.Security.fn_can_open_submission(submission)); 
        utils.set_disabled_state(this.$claim_button, !SEAD.Security.fn_can_claim_submission(submission));
        utils.set_disabled_state(this.$unclaim_button, !SEAD.Security.fn_can_unclaim_submission(submission));
        utils.set_disabled_state(this.$transfer_button, !SEAD.Security.fn_can_transfer_submission(submission));
    },

    submissionDeselected: function()
    {
        this.reset_status();
    },
    
    open: function (e)
    {
        if (this.selected_submission_id > 0) {
            SEAD.Router.navigate("submission/" + this.selected_submission_id.toString() + "/open", true);
        }
    },

    claim: function (e)
    {
        this.xclaim("claim");
    },
    
    unclaim: function (e)
    {
        this.xclaim("unclaim");
    },

    xclaim: function (action)
    {
        var submission = this.getSelected();
        this.claimView = new XClaimView({ action: action, submission: submission });
        $("#modal_view_container").html(this.claimView.render().el);
        this.listenTo(this.claimView, "submission-xclaimed", this.xclaimed_done );
        this.claimView.open("claim");
    },
    
    xclaimed_done: function (submission, action)
    {
        console.log("submission " + action + " event catched: TODO update table");
        this.tableView.updateRow(submission);
        //this.claimView.destroy();
    },
    
    
    transfer: function (e)
    {
        var users = new UserCollection();
        this.transferView = new TransferView({ submission: this.getSelected(), users: users });
        $("#modal_view_container").html(this.transferView.render().el);
        users.reset(SEAD.BootstrapData.Users, { reset: true });
        this.listenTo(this.transferView, "submission-transfered", this.transfer_done );
        this.transferView.open();
    },
 
    transfer_done: function (submission)
    {
        this.tableView.updateRow(submission);
        this.transferView.destroy();
    },
    
    getSelected: function()
    {
        return this.submissions.findWhere({ submission_id: this.selected_submission_id });
    }
    
});

window.SubmissionListView = Backbone.View.extend({

    submissions : null,
    table: null,
    
    initialize: function (options) {
        this.options = options || {};
        this.submissions = options.submissions;
    },
    
    render: function () {

        var self = this;
        var data = this.submissions.toJSON();
        var placeholder = $("<table>", {
            class: "display table table-condensed sead-smaller-font-size",
            id: "submission-list",
            cellpadding: "0",
            cellspacing: "0",
            border: "0"
        });
        
        var state_classes = [ "text-danger",  "text-muted", "text-warning", "text-primary", "text-success", "text-danger" ];
                
        this.$el.append(placeholder);
  
        this.table = $("#submission-list", this.$el)
                .bind('page',   function () { self.trigger("paging-occurred"); })
                .dataTable(
        {
            "sDom": "T<'clear'><'toolbar'>frt<'sead-smaller-font-size'ip><'row-fluid'<'span6'l><'span6'f>r>",
            "aaData": data,
            "aoColumns": [
                { "sTitle": "ID", "mData": "submission_id", "bVisible": true },
                { "sTitle": "Client", "mData": "x_full_name", "sClass": "text-left" },
                { "sTitle": "Grade", "mData": "x_data_provider_grade", "sClass": "text-center visible-lg" },
                { "sTitle": "Proxy", "mData": "data_types", "sClass": "text-left" },
                { "sTitle": "Date", "mData": "upload_date", "sClass": "text-left" },
                { "sTitle": "Status", "mData": "x_submission_state_name", "sClass": "text-center",
                    "fnCreatedCell": function (td, value, data, row_index, column_index) {
                        var state_id = data["submission_state_id"];
                        $(td).addClass(state_id < (state_classes.length - 1) ? state_classes[state_id] :  state_classes[0]);
                    }
                },
                { "sTitle": "Claimed by", "mData": "claim_full_name"},
                { "sTitle": "Date", "mData": "claim_date_time", "sClass": "text-left visible-lg" }
            ],
            "aaSorting": [[ 3, "desc" ]],
            "bPaginate": true,
            "bLengthChange": false,
            "bFilter": false,
            "bSort": true,
            "bInfo": true,
            "bAutoWidth": true,

            "fnCreatedRow": function(row, data, index) {
                var $row = $(row);
                $row.attr("id", "rowid_" + data["submission_id"].toString());
                $row.attr("rowindex", index.toString());
            },

            "oTableTools": {
                "fnRowSelected": function ( nodes ) {
                    var id = parseInt($($('td:first-child', nodes[0])[0]).text());
                    var index = parseInt($(nodes[0]).attr("rowindex"));
                    self.trigger("submission-selected", id, index);
                },
                "fnRowDeselected": function()
                {
                    self.trigger("submission-deselected");
                },
                "sRowSelect": "single",
                "sSelectedClass": "row_selected",
                "aButtons": []
            }

        });       
        
        $(this.el).find("div.toolbar").html(TemplateStore.get("template_submission_list_toolbar")());

        
        return this;
    },
    
    updateRow: function(data)
    {
        try {
            this.submissions.findWhere({submission_id: data["submission_id"]}).set(data);
            var rowid = "rowid_" + data["submission_id"].toString();
            this.table.fnUpdate(data, this.table.$("#" + rowid)[0]);
        } catch (ex) {
            alert(ex);
            this.table.fnDraw();
        }
    }

});

window.InformationBaseView = Backbone.View.extend({

    initialize: function (options) {
        this.options = options || {};
        this.render();
    },
    
    render: function () {
        try {
            $(this.el).html(this.createContent());
        } catch (ex) {
        }
        return this;
    }
    
});

window.LatestSitesView = window.InformationBaseView.extend({

    createContent: function () {
        return $(TemplateStore.get("template_LatestSitesView")({ data: SEAD.BootstrapData.Lookup.LatestSites }));
    }

});

window.DocumentationListView = window.InformationBaseView.extend({

    createContent: function () {
        var data = SEAD.BootstrapData.Lookup.References;
        var content = $("<ul/>", { class: "sead-smaller-font-size" });
        for (var i = 0; i < data.length; i++) {
            $("<li/>").append(
                    data[i].info_reference_type === "link"
                        ? $("<a/>", { href: (data[i].href || ""), target: "_blank", text: (data[i].display_name || "")})
                        : $("<p/>", { text: (data[i].display_name || "")})
            ).appendTo(content);
        }
        return content;
    }

});