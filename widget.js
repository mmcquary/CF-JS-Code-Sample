//--------------------------------------------------------------------------------------------------
/* Simplify jstree calls */
var ref_tree;
/* Store website base path */
var base_url_full;
/* Prevent multiple calls of key down actions */
var allow_key_action = true;
//--------------------------------------------------------------------------------------------------
function do_test() {
	var node_id_selected = ref_tree.get_selected();
	console.log(node_id_selected);
}
//--------------------------------------------------------------------------------------------------
function widget_initialize(set_base_url_full) {

	base_url_full = set_base_url_full;

	/************************************************************************************/
	/* Buttons */
	$('#add_widget').on('click', function (event, data) { add_widget(); });
	$('#delete_widget').on('click', function (event, data) { delete_widget(); });
	$('#print_branch').on('click', function (event, data) { print_branch(); });
	$('#search').on('click', function (event, data) { search_tree(); });
	$('#test').on('click', function (event, data) { do_test(); });

	/************************************************************************************/
	/* Tree */
	$('#widget_tree')
		.on('select_node.jstree', function (event, data) {
			load_widget_record();
			$('.widget-record-container').css('visibility', 'visible');
		})
		.on('deselect_node.jstree', function (event, data) {
			$('.widget-record-container').css('visibility', 'hidden');
		})
		.on('move_node.jstree', function (event, data) {
			if (data.parent == '#') {
				data.parent = 'tree-id-0';
			}
			move_widget(data.node.id.substring(8), data.parent.substring(8), data.position);
		})
		.on('open_node.jstree', function (event, data) {
			set_tree_state(data.node.id.substring(8), 'OPENED');
		})
		.on('close_node.jstree', function (event, data) {
			set_tree_state(data.node.id.substring(8), 'CLOSED');
		})
		.jstree({
			'core': {
				  'check_callback': true
				, 'multiple': false
			}
			, 'search': {
				  'show_only_matches': true
				, 'show_only_matches_children': true
				//, 'fuzzy': true
			}
			, 'plugins': [
				  'dnd'
				, 'search'
			]
		});

	ref_tree = $('#widget_tree').jstree(true);

	/************************************************************************************/
	/* Window Resize */
	/* Second resize is needed to bootstrap resize on page load */
	$(window).resize( function() {
		$("#widget_tree").height(
			  $(window).height()
			- $('.widget-tree-control-bar').outerHeight()
			- (
				  $('.widget-main-container').outerHeight()
				- $('.widget-main-container').height()
			  )
			- (
				  $('.widget-tree-container').outerHeight()
				- $('.widget-tree-container').height()
			  )
		);
	} ).resize();

	/************************************************************************************/
	/* Hot Keys */
	$(document).keydown( function(e) {
		if (e.ctrlKey && e.altKey && allow_key_action) {
			switch(e.which) {
				case 37: // Left
					block_repeating_keys();
					var node_id_selected = ref_tree.get_selected();
					var node_id_parent = ref_tree.get_parent(node_id_selected);
					console.log(node_id_selected);
					console.log(node_id_parent);
					ref_tree.deselect_node(node_id_selected);
					ref_tree.select_node(node_id_parent);
					break;

				//case 38: // Up
				//	break;

				case 39: // Right
					block_repeating_keys();
					var node_id_selected = ref_tree.get_selected();
					if (ref_tree.is_parent(node_id_selected)) {
						var node_id_children = ref_tree.get_children_dom(node_id_selected);
						ref_tree.deselect_node(node_id_selected);
						ref_tree.select_node(node_id_children[0]);
						console.log(node_id_selected);
						console.log(node_id_children[0]);
					}
					break;

				//case 40: // Down
				//	break;

				case 65: // A
					block_repeating_keys();
					add_widget();
					break;

				case 67: // C
					block_repeating_keys();
					ref_tree.close_all();
					break;

				case 70: // F
					$('#tree_search_term').focus()
					$('#tree_search_term').select();
					break;

				case 83: // S
					block_repeating_keys();
					widget_save();
					break;

			}
			e.preventDefault();
		}
	} );
	$('#tree_search_term').keydown( function(e) {
		if (e.which === 13) {
			search_tree();
			$('#tree_search_term').val('');
			e.preventDefault();
		}
	} );
	/************************************************************************************/
}
//--------------------------------------------------------------------------------------------------
function widget_record_initialize() {
	/************************************************************************************/
	/* Buttons */
	$('#button_save').on('click', function() { widget_save(); });
	$('#button_done').on('click', function() { widget_done(); });
	$('#button_delete_log_entry').on('click', function() { delete_done_log_entry(this); });
	
	/************************************************************************************/
	/* Date Picker */
	var the_date = new Date();
	console.log(the_date);
	$('#due_dt').datepicker( {
		  numberOfMonths: 2
	} );
	$('#done_dt_date').datepicker();
}
//--------------------------------------------------------------------------------------------------
function add_widget() {
	var node_id_selected = ref_tree.get_selected();

	var widget_parent_id;
	if (node_id_selected.length == 0) {
		// Special case for root node
		node_id_selected[0] = '#';
		widget_parent_id = 0;
	} else {
		widget_parent_id = node_id_selected[0].substring(8);
	}

	$.ajax( {
		  url: base_url_full + '/cfcs/widget.cfc'
		, dataType: 'json'
		, data: {
			  method: 'storeWidgetRecord'
			, returnFormat: 'json'
			, widget_id: 0
			, widget_parent_id: widget_parent_id
			, widget_name: 'New'
			, widget_type: 'Category'
		}
		, success: function(response) {
			var new_node = {
				  id: 'tree-id-' + response.WIDGET_ID
				, text: ' New'
				, icon: '/images/icon-no-date.png'
			};
			ref_tree.create_node(node_id_selected[0], new_node, 'first');
			ref_tree.open_node(node_id_selected);
			ref_tree.deselect_node(node_id_selected);
			ref_tree.select_node(new_node);
		}
		, error: function(xhr, status, error) {
			alert(error);
		}
	} );
}
//--------------------------------------------------------------------------------------------------
function widget_save() {
	var node_id_selected = ref_tree.get_selected();
	var do_save = true;

	if (
		(
			   $('#recur_i_days').val()
			|| $('#recur_i_months').val()
			|| $('#notify_i_days').val()
			|| $('#notify_i_months').val()
		)
		&& !$('#due_dt').val().length
	) {
		do_save = false;
		alert('A due date must be supplied for recurring or notification dates.');
	}

	if (do_save) {
		$.ajax( {
			  url: base_url_full + '/cfcs/widget.cfc'
			, dataType: 'json'
			, data: {
				  method: 'storeWidgetRecord'
				, returnFormat: 'json'
				, widget_id: $('#widget_id').val()
				, widget_parent_id: $('#widget_parent_id').val()
				, widget_name: $('#widget_name').val()
				, widget_type: $('#widget_type').val()
				, due_dt: $('#due_dt').val()
				, recur_i_days: $('#recur_i_days').val()
				, recur_i_months: $('#recur_i_months').val()
				, notify_i_days: $('#notify_i_days').val()
				, notify_i_months: $('#notify_i_months').val()
				, comment: $('#comment').val()
			}
			, success: function(response) {
				ref_tree.rename_node( node_id_selected, ' ' + $('#widget_name').val() );
				ref_tree.set_icon(node_id_selected, response.ICON_URI);
				load_widget_record();
			}
			, error: function(xhr, status, error) {
				alert(error);
			}
		} );
	}
}
//--------------------------------------------------------------------------------------------------
function delete_widget() {
	var node_id_selected = ref_tree.get_selected();
	var widget_id = node_id_selected[0].substring(8);

	$.ajax( {
		  url: base_url_full + '/cfcs/widget.cfc'
		, data: {
			  method: 'deleteWidgetRecord'
			, widget_id: widget_id
		}
		, success: function(response) {
			ref_tree.delete_node(node_id_selected);
			$('.widget-record-container').html('');
			$('.widget-record-container').css('visibility', 'hidden');
		}
		, error: function(xhr, status, error) {
			alert(error);
		}
	} );
}
//--------------------------------------------------------------------------------------------------
function move_widget(node_id, new_parent_id, position) {
	$.ajax( {
		  url: base_url_full + '/cfcs/widget.cfc'
		, data: {
			  method: 'moveWidgetRecord'
			, widget_id_move: node_id
			, new_parent_id: new_parent_id
			, new_sequence: position + 1 //zero-based to one-based
		}
		, success: function(response) {
		}
		, error: function(xhr, status, error) {
			alert(error);
			ref_tree.refresh();
		}
	} );
}
//--------------------------------------------------------------------------------------------------
function set_tree_state(node_id, tree_state) {
	$.ajax( {
		  url: base_url_full + '/cfcs/widget.cfc'
		, data: {
			  method: 'setTreeStateWidgetRecord'
			, widget_id: node_id
			, tree_state: tree_state
		}
		, success: function(response) {
		}
		, error: function(xhr, status, error) {
			alert(error);
		}
	} );
}
//--------------------------------------------------------------------------------------------------
function load_widget_record() {
	var node_id_selected = ref_tree.get_selected();

	$.ajax( {
		  url: base_url_full + '/widget-record.cfm'
		, data: {
			  widget_id: node_id_selected[0].substring(8)
		}
		, success: function(response) {
			$('.widget-record-container').html(response);
			$('#widget_name').focus();
			$('#widget_name').select();
		}
		, error: function(xhr, status, error) {
			alert(error);
		}
	} );
}
//--------------------------------------------------------------------------------------------------
function widget_done() {
	var node_id_selected = ref_tree.get_selected();

	var done_dt_format = '';
	if ( $('#done_dt_date').val() ) {
		done_dt_format = $('#done_dt_date').val()
	}
	if ( $('#done_dt_hour').val()
		&& $('#done_dt_minute').val()
		&& $('#done_dt_tm').val()
	) {
		done_dt_format += ' ' + $('#done_dt_hour').val()
			+ ':' + $('#done_dt_minute').val()
			+ ' ' + $('#done_dt_tm').val();
	}
	$.ajax( {
		  url: base_url_full + '/cfcs/widget.cfc'
		, dataType: 'json'
		, data: {
			  method: 'setDoneWidgetRecord'
			, returnFormat: 'json'
			, widget_id: $('#widget_id').val()
			, done_dt: done_dt_format
			, done_comment: $('#done_comment').val()
		}
		, success: function(response) {
			load_widget_record();
			ref_tree.set_icon(node_id_selected, response.ICON_URI);
		}
		, error: function(xhr, status, error) {
			alert(error);
		}
	} );
}
//--------------------------------------------------------------------------------------------------
function delete_done_log_entry(e_this) {
	var widget_done_log_id = e_this.dataset.id;

	$.ajax( {
		  url: base_url_full + '/cfcs/widget.cfc'
		, data: {
			  method: 'deleteDoneLogEntry'
			, widget_done_log_id: widget_done_log_id
		}
		, success: function(response) {
			load_widget_record();
		}
		, error: function(xhr, status, error) {
			alert(error);
		}
	} );

}
//--------------------------------------------------------------------------------------------------
function search_tree() {
	ref_tree.search( $('#tree_search_term').val() );
}
//--------------------------------------------------------------------------------------------------
function print_branch() {
	var node_selected = ref_tree.get_selected();
	if (node_selected.length) {
		window.open(
			base_url_full
				+ '/print-branch.cfm'
				+ '?widget_parent_id=' + node_selected[0].substring(8)
			, '_blank'
		);
	}
}
//--------------------------------------------------------------------------------------------------
function block_repeating_keys() {
	allow_key_action = false;
	setTimeout( function() {
		allow_key_action = true;
	}, 250);
}
//--------------------------------------------------------------------------------------------------
