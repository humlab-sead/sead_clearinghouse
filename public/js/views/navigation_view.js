window.SubmissionNavigationView = Backbone.View.extend({

    initialize: function () {

        this.template = TemplateStore.get("template_SubmissionNavigationView");

        this.submission_id = this.options.submission_id;
        this.submission_metadata_model = this.options.submission_metadata_model;
        
        this.reports = this.options.reports;

        this.sitesView = new SubmissionSitesNavigationView( { submission_metadata_model: this.submission_metadata_model });
        this.reportsView = new SubmissionReportsNavigationView({ submission_id: this.submission_id, reports: this.reports });
        this.tablesView = new SubmissionTablesNavigationView({ submission_id: this.submission_id, xml_tables_list: this.options.xml_tables_list });

        this.listenTo(this.submission_metadata_model, 'reset', this.renderSites);
        this.listenTo(this.submission_metadata_model, 'change', this.renderSites);
        this.listenTo(this.reports, 'reset', this.renderReports);
        this.listenTo(this, 'render:complete', this.assignToggler);
        this.listenTo(this.tablesView, 'render:complete', this.renderCompleteNotifier);
        
    },

    events: {
        'render:complete': 'renderComplete'
    },
            
    render: function () {

        this.renderCounter = 3;
        
        $(this.el).html(this.template());

        $('#container_SubmissionTablesNavigationView', this.$el).html(this.tablesView.render().el);
        
        return this;

    },
            
    renderSites: function () {
        
        var container = $('#container_SubmissionSitesNavigationView', this.$el);
        
        container.html(this.sitesView.render().el);
        container.children().children().unwrap(); // Remove surrounding div that underscore adds to inserted fragment

        this.renderCompleteNotifier();
        
        return this;

    },

    renderReports: function () {
        
        var container = $('#container_SubmissionReportsNavigationView', this.$el);
        container.html(this.reportsView.render().el);
        container.children().children().unwrap();
        
        this.renderCompleteNotifier();

        return this;

    },
    
    renderCompleteNotifier: function()
    {
        this.renderCounter--;
        if (this.renderCounter <= 0) {
            var self = this;
            $("a.tree-link", this.$el).click(
                function (e) {
                    $("a.tree-link-selected", self.$el).removeClass("tree-link-selected");
                    $(this).addClass("tree-link-selected");
                }
            );
            this.trigger("render:complete");
        }
    },
    
    assignToggler: function()
    {
        TreeNodeHelper.assignToggler(this.$el);
    },
    
    renderSiteStatus: function(rejects)
    {
        try {
            $("span[site_id]", this.$el).each(
                function () {
                    $(this).toggleClass("rejected-site", rejects.contains_site_id(parseInt($(this).attr("site_id"))));
                }
            );
        } catch (ex) {
            console.log(ex.message || ex);
        }
    }

});

window.SubmissionSitesNavigationView = Backbone.View.extend({

    initialize: function () {

        this.rootTemplate = TemplateStore.get("template_SiteRootView");
        this.nodeTemplate = TemplateStore.get("template_SiteNodeView");
        this.sampleGroupNodeTemplate = TemplateStore.get("template_SampleGroupNodeView");
        this.sampleNodeTemplate = TemplateStore.get("template_SampleNodeView");
        this.datasetNodeTemplate = TemplateStore.get("template_DatasetNodeView");

        this.submission_metadata_model = this.options.submission_metadata_model;
        
    },
            
    render: function () {
        
        var metadata = this.submission_metadata_model.toJSON();
        var sites = metadata.sites;
        
        $(this.el).html(this.rootTemplate({ site_count: sites.length}));

        var $site_list = $("#template_site_list_placeholder", this.$el);
        
        for (var i = 0; i < sites.length; i++) {
            
            var site = sites[i];
            
            $site_list.append(this.nodeTemplate({ site: site }));
            
            if (site.sample_groups.length == 0) {
                continue;
            }
            
            var $sample_group_list = $("#site_" + site.site_id.toString() + "_sample_groups_placeholder", this.$el);

            for (var j = 0; j < site.sample_groups.length; j++) {
                
                var sample_group =  site.sample_groups[j];

                $sample_group_list.append(this.sampleGroupNodeTemplate({ sample_group: sample_group }));
                
                var $sample_list = $("#sample_group_" + sample_group.sample_group_id.toString() + "_placeholder", this.$el);

                for (k = 0;k < sample_group.samples.length; k++) {
                    var sample = sample_group.samples[k];     
                    $sample_list.append(this.sampleNodeTemplate({ sample: sample }));
                }
                
                var $dataset_placeholder = $("#sample_group_" + sample_group.sample_group_id.toString() + "_datasets_placeholder", this.$el);

                for (var d = 0;d < sample_group.datasets.length; d++) {
                    var dataset = sample_group.datasets[d];     
                    $dataset_placeholder.append(this.datasetNodeTemplate({ submission_id: site.submission_id, site_id: site.site_id, dataset: dataset }));
                }

            }
        }
        return this;
    }

});

window.SubmissionReportsNavigationView = Backbone.View.extend({

    initialize: function () {
        this.rootTemplate = TemplateStore.get("template_SubmissionReportsNavigationView");
        this.nodeTemplate = TemplateStore.get("template_SubmissionReportNavigationNode");
        this.reports = this.options.reports;
        this.submission_id = this.options.submission_id;
    },
            
    render: function () {
        
        var reports = this.reports.toJSON();

        $(this.el).html(this.rootTemplate({ report_count: reports.length }));
        
        var $list = $("#report_list_placeholder", this.$el);
        
        for (var i = 0; i < reports.length; i++) {
            $list.append(this.nodeTemplate({ submission_id: this.submission_id, report: reports[i] }));
        }
        return this;
    }
});

window.SubmissionTablesNavigationView = Backbone.View.extend({

    initialize: function () {
        this.rootTemplate = TemplateStore.get("template_SubmissionTablesNavigationView");
        this.nodeTemplate = TemplateStore.get("template_SubmissionTablesNavigationNode");
        this.xml_tables_list = this.options.xml_tables_list;
        this.listenTo(this.xml_tables_list, 'reset', this.renderLeafs);
        this.listenTo(this.xml_tables_list, 'change', this.renderLeafs);
    },
    
    render: function()
    {
        $(this.el).html(this.rootTemplate());
        return this;
    },
    
    renderLeafs: function()
    {
        var tables = this.xml_tables_list.toJSON();
        var $root = $("#tables_list_placeholder", this.$el);
        $("#xml_table_count", this.$el).html(tables.length.toString());
        for (var i = 0; i < tables.length; i++) {
            $root.append(this.nodeTemplate({ submission_id: this.options.submission_id, item: tables[i] }));
        }
        $('#container_SubmissionTablesNavigationView').children().children().unwrap();            
        this.trigger("render:complete");
        return this;
    }
});

var TreeNodeHelper = {
    
    assignToggler: function(context)
    {
        $('.tree li:has(ul)', context).addClass('parent_li').find(' > span').attr('title', 'Collapse this branch');
        
        $('.tree li.parent_li > span', context).on('click', function (e) {
            var children = $(this).parent('li.parent_li').find(' > ul > li');
            if (children.is(":visible")) {
                children.hide(0); //'fast');
                $(this).attr('title', 'Expand this branch').find(' > i').addClass('glyphicon-plus-sign').removeClass('glyphicon-minus-sign');
            } else {
                children.show(0); ('fast');
                $(this).attr('title', 'Collapse this branch').find(' > i').addClass('glyphicon-minus-sign').removeClass('glyphicon-plus-sign');
            }
            e.stopPropagation();
        }); 
        return this;
    }
    
};


