<!---
Important:
Purpose:
Development:
Input:
Notes:
History:
	09/05/15 mm - Created
--->
<cfcomponent output="false">

<!--- URLs --->
<cfset THIS.BASE_URL = "" />
<cfset THIS.BASE_URL_FULL = "http://druid.com" & THIS.BASE_URL />

<!--- Constants --->
<cfset THIS.ROOT_ID = 0 />
<cfset THIS.WIDGET_TYPES = "Category,Task" />

<!---
<cfset LOCAL.DB = {} />
<cfset LOCAL.DB.widget_parent_id = {
	  value: ARGUMENTS.widget_parent_id
	, cfsqltype: "CF_SQL_INTEGER"
} />
--->

<!------------------------------------------------------------------------------------------------->
<!--- Widget Data Section --->
<!------------------------------------------------------------------------------------------------->
<!---
<cffunction name="getWidgetData" returntype="query" access="public" output="false">

	<cfquery name="LOCAL.widget_data">
		SELECT w.widget_id, w.widget_name, INITCAP(w.widget_type) AS widget_type
		  FROM widget w
		 ORDER BY w.widget_type, w.widget_name
	</cfquery>

	<cfreturn LOCAL.widget_data />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="getWidgetTreeData" returntype="query" access="public" output="false">

	<cfquery name="LOCAL.widget_data">
		SELECT w.widget_id, w.widget_name, INITCAP(w.widget_type) AS widget_type
		  FROM widget w
		 ORDER BY w.widget_parent_id, w.widget_type, w.widget_name
	</cfquery>

	<cfreturn LOCAL.widget_data />
</cffunction>
--->
<!------------------------------------------------------------------------------------------------->
<cffunction name="getWidgetChildrenData" returntype="query" access="remote" output="false">
	<cfargument name="widget_parent_id" type="numeric" required="true" />

	<cfquery name="LOCAL.widget_data">
		SELECT w.widget_id, w.widget_name, UPPER(w.widget_type) AS widget_type
			 , w.due_dt, COALESCE(w.is_done, false) AS is_done
			 , CAST(w.recur_i AS text) AS recur_i
			 , CAST(w.notify_i AS text) AS notify_i
			 , w.comment
			 , w.tree_state
			 , w.sequence
		  FROM widget w
		 WHERE w.widget_parent_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_parent_id#" />
		   AND COALESCE(w.is_deleted, false) != true
		 ORDER BY w.sequence
	</cfquery>

	<cfreturn LOCAL.widget_data />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="getWidgetRecord" returntype="query" access="public" output="false">
	<cfargument name="widget_id" type="numeric" required="true" />

	<cfquery name="LOCAL.widget_record">
		SELECT w.widget_id, w.widget_parent_id, w.widget_name, UPPER(w.widget_type) AS widget_type
			 , w.due_dt, COALESCE(w.is_done, false) AS is_done
			 , CAST(w.recur_i AS text) AS recur_i
			 , CAST(w.notify_i AS text) AS notify_i
			 , w.comment
			 , w.tree_state
		  FROM widget w
		 WHERE w.widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
	</cfquery>

	<cfreturn LOCAL.widget_record />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="getWidgetBranchData" returntype="query" access="remote" output="false">
	<cfargument name="widget_parent_id" type="numeric" required="true" />
	<cfargument name="settings" type="struct" default="#structNew()#" />

	<cfparam name="ARGUMENTS.settings.date_flagged_only" default="false" />

	<cfquery name="LOCAL.tree_branch_data">
		WITH RECURSIVE r_widget(widget_id) AS (
			SELECT w.widget_id, w.widget_parent_id, w.widget_name, UPPER(w.widget_type) AS widget_type
				 , w.due_dt, COALESCE(w.is_done, false) AS is_done
				 , w.recur_i, w.notify_i
				 , w.comment
				 , w.tree_state
			  FROM widget w
			 WHERE widget_parent_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_parent_id#" />
			   AND COALESCE(w.is_deleted, false) != true
			 UNION ALL
			SELECT w.widget_id, w.widget_parent_id, w.widget_name, UPPER(w.widget_type) AS widget_type
				 , w.due_dt, COALESCE(w.is_done, false) AS is_done
				 , w.recur_i, w.notify_i
				 , w.comment
				 , w.tree_state
			  FROM r_widget r_w, widget w
			 WHERE r_w.widget_id = w.widget_parent_id
			   AND COALESCE(w.is_deleted, false) != true
		)
		SELECT r_w.widget_id, r_w.widget_parent_id, r_w.widget_name, UPPER(r_w.widget_type) AS widget_type
			 , r_w.due_dt, COALESCE(r_w.is_done, false) AS is_done
			 , CAST(r_w.recur_i AS text) AS recur_i
			 , CAST(r_w.notify_i AS text) AS notify_i
			 , r_w.comment
			 , r_w.tree_state
		  FROM r_widget r_w
	<cfif ARGUMENTS.settings.date_flagged_only>
		 WHERE r_w.due_dt - r_w.notify_i <= current_date
		    OR r_w.due_dt <= current_date
		   AND COALESCE(r_w.is_done, false) = false
	</cfif>
	</cfquery>

	<cfreturn LOCAL.tree_branch_data />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="getWidgetDoneLogData" returntype="query" access="public" output="false">
	<cfargument name="widget_id" type="numeric" required="true" />
	<cfargument name="record_limit" type="numeric" required="false" />

	<cfquery name="LOCAL.done_log">
		SELECT dl.widget_done_log_id, dl.done_dt, dl.done_comment
		  FROM widget_done_log dl
		 WHERE dl.widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
		 ORDER BY dl.done_dt DESC
	<cfif structKeyExists(ARGUMENTS, "record_limit")>
		 LIMIT <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.record_limit#" />
	</cfif>
	</cfquery>

	<cfreturn LOCAL.done_log />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="getWidgetDailyActivity" returntype="query" access="public" output="false">

	<cfquery name="LOCAL.daily_activity">
		SELECT w.widget_name
			 , dl.done_comment
		  FROM widget w, widget_done_log dl
		 WHERE w.widget_id = dl.widget_id
		   AND date_trunc('day', dl.done_dt) = current_date
		 ORDER BY dl.done_dt DESC
	</cfquery>

	<cfreturn LOCAL.daily_activity />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<!------------------------------------------------------------------------------------------------->

<!------------------------------------------------------------------------------------------------->
<!--- Widget Data Change Section --->
<!------------------------------------------------------------------------------------------------->
<cffunction name="storeWidgetRecord" returntype="struct" access="remote" output="false">
	<cfargument name="widget_id" type="numeric" required="true" />
	<cfargument name="widget_parent_id" type="numeric" required="true" />
	<cfargument name="widget_name" type="string" required="true" />
	<cfargument name="widget_type" type="string" required="true" />
	<cfargument name="due_dt" type="string" default="" />
	<cfargument name="recur_i_days" type="string" default="" />
	<cfargument name="recur_i_months" type="string" default="" />
	<cfargument name="notify_i_days" type="string" default="" />
	<cfargument name="notify_i_months" type="string" default="" />
	<cfargument name="comment" type="string" default="" />

	<!--- Create Components --->
	<cfset LOCAL.di = new _cfcs.db_interval() />

	<cfset LOCAL.return_info = {} />

	<cfset LOCAL.return_info.widget_id = ARGUMENTS.widget_id />

	<!---
	<cfset LOCAL.new_sequence = getWidgetChildrenData(ARGUMENTS.widget_parent_id).recordcount + 1 />
	--->
	
	<cfif NOT ARGUMENTS.widget_id GT 0>
		
		<cftransaction>
		
		<!--- Increment sequence of all parent children to put new record first --->
		<cfquery name="LOCAL.increment_children_sequence">
			UPDATE widget
			SET sequence = sequence + 1
			WHERE widget_parent_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_parent_id#" />
		</cfquery>

		<cfquery name="LOCAL.add">
			INSERT INTO widget (widget_parent_id, widget_name, widget_type, sequence)
			VALUES (
				  <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_parent_id#" />
				, <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.widget_name#" />
				, <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.widget_type#" />
				, <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="1" />
			)
		</cfquery>
		
		<cfquery name="LOCAL.get_id">
			SELECT CURRVAL( PG_GET_SERIAL_SEQUENCE('widget','widget_id') ) AS widget_id
		</cfquery>

		</cftransaction>
		
		<cfset LOCAL.return_info.widget_id = LOCAL.get_id.widget_id />

	<cfelse>
		<!--- Create notify interval --->
		<cfset LOCAL.notify_i = LOCAL.di.dbInterval( argumentCollection={
			  days = ARGUMENTS.notify_i_days
			, months = ARGUMENTS.notify_i_months
		} ) />
		<!--- Create recur interval --->
		<cfset LOCAL.recur_i = LOCAL.di.dbInterval( argumentCollection={
			  days = ARGUMENTS.recur_i_days
			, months = ARGUMENTS.recur_i_months
		} ) />
		
		<cfquery name="LOCAL.edit">
			UPDATE widget
			   SET widget_name = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.widget_name#" />
				 , widget_type = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.widget_type#" />
				 , due_dt = <cfqueryparam cfsqltype="CF_SQL_DATE" value="#ARGUMENTS.due_dt#" />
		<cfif isDate(ARGUMENTS.due_dt)
			AND len(LOCAL.notify_i)
		>
				 , notify_i = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#LOCAL.notify_i#" />
					::interval
		<cfelse>
				 , notify_i = NULL
		</cfif>
		<cfif isDate(ARGUMENTS.due_dt)
			AND len(LOCAL.recur_i)
		>
				 , recur_i = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#LOCAL.recur_i#" />
					::interval
		<cfelse>
				 , recur_i = NULL
		</cfif>
				 , comment = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.comment#" />
				 , is_done = false
			 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
		</cfquery>
	</cfif>

	<cfset LOCAL.return_info.icon_uri = getIconUri(LOCAL.return_info.widget_id) />

	<cfreturn LOCAL.return_info />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="deleteWidgetRecord" returntype="void" access="remote" output="false">
	<cfargument name="widget_id" type="numeric" required="true" />

	<!--- Do not allow a delete if children exist --->
	<cfquery name="LOCAL.check_children">
		SELECT 1
		  FROM widget
		 WHERE widget_parent_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
		   AND is_deleted = false
	</cfquery>
	<cfif NOT LOCAL.check_children.recordcount>
		<cftransaction>

		<cfquery name="LOCAL.update">
			UPDATE widget
			   SET is_deleted = true
			 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
		</cfquery>
		<!--- If a new record, fully delete it --->
		<cfquery name="LOCAL.delete">
			DELETE FROM widget
			 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
			   AND widget_name = 'New'
		</cfquery>

		<!---

		<cfquery name="LOCAL.delete">
			DELETE FROM widget
			 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
		</cfquery>

		<cfquery name="LOCAL.delete_log">
			DELETE FROM widget_done_log
			 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
		</cfquery>

		--->

		</cftransaction>
	</cfif>

	<cfreturn />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="moveWidgetRecord" returntype="void" access="remote" output="false">
	<cfargument name="widget_id_move" type="numeric" required="true" />
	<cfargument name="new_parent_id" type="numeric" required="true" />
	<cfargument name="new_sequence" type="numeric" required="true" />

	<cfset LOCAL.parent_children_data = getWidgetChildrenData(ARGUMENTS.new_parent_id) />

	<cftransaction>

	<cfset LOCAL.sequence = 1 />
	<cfloop query="LOCAL.parent_children_data">
		<cfif NOT widget_id EQ ARGUMENTS.widget_id_move>
			<!--- Skip sequence of moving widget target unless it equals itself --->
			<cfif LOCAL.sequence EQ ARGUMENTS.new_sequence>
				<cfset LOCAL.sequence += 1 />
			</cfif>
			<cfquery name="LOCAL.move_widget">
				UPDATE widget
				   SET sequence = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#LOCAL.sequence#" />
				 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#widget_id#" />
			</cfquery>
			<cfset LOCAL.sequence += 1 />
		</cfif>
	</cfloop>

	<cfquery name="LOCAL.move_widget">
		UPDATE widget
		   SET widget_parent_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.new_parent_id#" />
			 , sequence = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.new_sequence#" />
		 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id_move#" />
	</cfquery>

	</cftransaction>

	<cfreturn />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="setDoneWidgetRecord" returntype="struct" access="remote" output="false">
	<cfargument name="widget_id" type="numeric" required="true" />
	<cfargument name="done_dt" type="string" required="true" />
	<cfargument name="done_comment" type="string" required="true" />

	<cfset LOCAL.return_info = {} />

	<!--- Check to make sure the widget is not already done --->
	<cfquery name="LOCAL.check_done">
		SELECT due_dt, recur_i, COALESCE(is_done, false) AS is_done
		  FROM widget
		 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
	</cfquery>

	<cfif NOT LOCAL.check_done.is_done>
		<cftransaction>
		
		<cfif isDate(LOCAL.check_done.due_dt)
			AND len(LOCAL.check_done.recur_i)
			AND isDate(ARGUMENTS.done_dt)
		>
			<cfquery name="LOCAL.set_recur">
				UPDATE widget
				   SET due_dt = CAST(<cfqueryparam cfsqltype="CF_SQL_TIMESTAMP" value="#ARGUMENTS.done_dt#" /> AS timestamp) + recur_i
				 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
			</cfquery>
		<cfelse>
			<cfquery name="LOCAL.set_done">
				UPDATE widget
				   SET is_done = true
					 , due_dt = NULL
				 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
			</cfquery>
		</cfif>

		<cfquery name="LOCAL.add_done_log">
			INSERT INTO widget_done_log (widget_id, done_dt, done_comment)
			VALUES (
				  <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
				, <cfqueryparam cfsqltype="CF_SQL_TIMESTAMP" value="#ARGUMENTS.done_dt#" />
				, <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.done_comment#" />
			)
		</cfquery>
			
		</cftransaction>
	</cfif>

	<cfset LOCAL.return_info.icon_uri = getIconUri(ARGUMENTS.widget_id) />

	<cfreturn LOCAL.return_info />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="deleteDoneLogEntry" returntype="void" access="remote" output="false">
	<cfargument name="widget_done_log_id" type="numeric" required="true" />

	<cfquery name="LOCAL.delete">
		DELETE FROM widget_done_log
		WHERE widget_done_log_id =
			<cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_done_log_id#" />
	</cfquery>

	<cfreturn />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="setTreeStateWidgetRecord" returntype="void" access="remote" output="false">
	<cfargument name="widget_id" type="numeric" required="true" />
	<cfargument name="tree_state" type="string" required="true" />

	<cfquery name="LOCAL.set_tree_state">
		UPDATE widget
		   SET tree_state = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ARGUMENTS.tree_state#" />
		 WHERE widget_id = <cfqueryparam cfsqltype="CF_SQL_INTEGER" value="#ARGUMENTS.widget_id#" />
	</cfquery>

	<cfreturn />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<!------------------------------------------------------------------------------------------------->

<!------------------------------------------------------------------------------------------------->
<!--- Utility Section --->
<!------------------------------------------------------------------------------------------------->
<cffunction name="getIconUri" returntype="string" access="remote" output="false">
	<cfargument name="widget_id" type="numeric" default="" />

	<!--- Create Components --->
	<cfset LOCAL.di = new _cfcs.db_interval() />

	<cfset LOCAL.widget_record = getWidgetRecord(ARGUMENTS.widget_id) />
	
	<!--- Set icons based upon various dates --->
	<cfset LOCAL.icon_uri = "/images/icon-no-date.png" />
	<cfset LOCAL.current_dt = dateFormat(now(), "MM/DD/YYYY") />
	<!--- Insure it is not already done and has a due date --->
	<cfif NOT LOCAL.widget_record.is_done
		AND isDate(LOCAL.widget_record.due_dt)
	>
		<cfset LOCAL.circle_color = "gray" />
		<!--- Calculate the absolute notify date from the due date and notify interval --->
		<cfset LOCAL.notify_dt = "" />
		<cfif len(LOCAL.widget_record.notify_i)>
			<cfset LOCAL.notify_dt = LOCAL.widget_record.due_dt />
			<cfset LOCAL.months_interval = LOCAL.di.intervalPart("mon", LOCAL.widget_record.notify_i) />
			<cfset LOCAL.notify_dt = dateAdd("M", -LOCAL.months_interval, LOCAL.notify_dt) />
			<cfset LOCAL.days_interval = LOCAL.di.intervalPart("day", LOCAL.widget_record.notify_i) />
			<cfset LOCAL.notify_dt = dateAdd("D", -LOCAL.days_interval, LOCAL.notify_dt) />
		</cfif>

		<!--- Check if overdue; set to red --->
		<cfif dateDiff("D", LOCAL.current_dt, LOCAL.widget_record.due_dt) LT 0>
			<cfset LOCAL.circle_color = "red" />
		<!--- Check if due today; set to green --->
		<cfelseif dateDiff("D", LOCAL.current_dt, LOCAL.widget_record.due_dt) EQ 0>
			<cfset LOCAL.circle_color = "green" />
		<!--- Check if past notify interval or due tomorrow; set to yellow --->
		<cfelseif isDate(notify_dt)
			AND (dateDiff("D", LOCAL.current_dt, LOCAL.notify_dt) LTE 0)
			<!--- OR (dateDiff("D", LOCAL.current_dt, LOCAL.widget_record.due_dt) EQ 1) --->
		>
			<cfset LOCAL.circle_color = "yellow" />
		</cfif>

		<cfset LOCAL.icon_uri = "/images/icon-circle-" & LOCAL.circle_color & ".png" />
	</cfif>

	<cfreturn LOCAL.icon_uri />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<cffunction name="getDateStatus" returntype="string" access="public" output="false">
	<cfargument name="widget_id" type="numeric" default="" />

	<!--- Create Components --->
	<cfset LOCAL.di = new _cfcs.db_interval() />

	<cfset LOCAL.widget_record = getWidgetRecord(ARGUMENTS.widget_id) />
	
	<!--- Set icons based upon various dates --->
	<cfset LOCAL.date_status = "DATE_UNKNOWN" />
	<cfset LOCAL.current_dt = dateFormat(now(), "MM/DD/YYYY") />
	<!--- Insure it is not already done and has a due date --->
	<cfif NOT LOCAL.widget_record.is_done
		AND isDate(LOCAL.widget_record.due_dt)
	>
		<cfset LOCAL.date_status = "DATE_FUTURE" />
		<!--- Calculate the absolute notify date from the due date and notify interval --->
		<cfset LOCAL.notify_dt = "" />
		<cfif len(LOCAL.widget_record.notify_i)>
			<cfset LOCAL.notify_dt = LOCAL.widget_record.due_dt />
			<cfset LOCAL.months_interval = LOCAL.di.intervalPart("mon", LOCAL.widget_record.notify_i) />
			<cfset LOCAL.notify_dt = dateAdd("M", -LOCAL.months_interval, LOCAL.notify_dt) />
			<cfset LOCAL.days_interval = LOCAL.di.intervalPart("day", LOCAL.widget_record.notify_i) />
			<cfset LOCAL.notify_dt = dateAdd("D", -LOCAL.days_interval, LOCAL.notify_dt) />
		</cfif>

		<!--- Check if overdue; set to red --->
		<cfif dateDiff("D", LOCAL.current_dt, LOCAL.widget_record.due_dt) LT 0>
			<cfset LOCAL.date_status = "DATE_OVERDUE" />
		<!--- Check if due today; set to green --->
		<cfelseif dateDiff("D", LOCAL.current_dt, LOCAL.widget_record.due_dt) EQ 0>
			<cfset LOCAL.date_status = "DATE_DUE_NOW" />
		<!--- Check if past notify interval or due tomorrow; set to yellow --->
		<cfelseif isDate(notify_dt)
			AND (dateDiff("D", LOCAL.current_dt, LOCAL.notify_dt) LTE 0)
			<!--- OR (dateDiff("D", LOCAL.current_dt, LOCAL.widget_record.due_dt) EQ 1) --->
		>
			<cfset LOCAL.date_status = "DATE_FUTURE_ALERT" />
		</cfif>
	</cfif>

	<cfreturn LOCAL.date_status />
</cffunction>
<!------------------------------------------------------------------------------------------------->
<!------------------------------------------------------------------------------------------------->
</cfcomponent>
