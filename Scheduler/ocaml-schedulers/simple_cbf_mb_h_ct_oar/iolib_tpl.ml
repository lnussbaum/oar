open DBD
open Types
open Interval
open Helpers

(*  Postgresql very sensible ? "type = \"default\""    "type = 'default'" *)


let connect () = DBD.connect ();;
let disconnect dbh = DBD.disconnect dbh;;


let get_resource_list (dbh)  = 
  let query = "SELECT resource_id, network_address, state, available_upto FROM resources" in
  let res = execQuery dbh query in
  let get_one_resource a =
    { resource_id = NoN int_of_string a.(0); (* resource_id *)
      network_address = NoNStr a.(1); (* network_address *)
      state = NoN rstate_of_string a.(2); (* state *)
      available_upto = NoN Int64.of_string a.(3) ;} (* available_upto *)
  in
    map res get_one_resource ;;


let get_available_uptos dbh =
  let query = "SELECT available_upto FROM resources GROUP BY available_upto" in
  let res = execQuery dbh query in 
  let get_one a = NoN Int64.of_string a.(0)  (* available_upto *)
    in
      map res get_one;;

(*                                                                             *)
(* get_job_list: retreive jobs to schedule with important relative information *)
(*                                                                             *)

let get_job_list dbh default_resources queue besteffort_duration =
  let flag_besteffort = if (queue == "besteffort") then true else false in
  let jobs = Hashtbl.create 1000 in (* Hashtbl.add jobs jid ( blabla *)
  let constraints = Hashtbl.create 10 in (* Hashtable of constraints to avoid recomputing of corresponding interval list*)

  let get_constraints j_ppt r_ppt = 
    if (j_ppt = "") && ( r_ppt = "type = 'default'" || r_ppt = "" ) then
      default_resources
    else
      let and_sql = if ((j_ppt = "") || (r_ppt = "")) then "" else " AND " in 
      let sql_cts = j_ppt ^ and_sql^ r_ppt in 
        try Hashtbl.find constraints sql_cts
        with Not_found ->
          begin  
            let query = Printf.sprintf "SELECT resource_id FROM resources WHERE state = 'Alive'  AND ( %s )"  sql_cts in
            let res = execQuery dbh query in 
            let get_one_resource a = 
              NoN int_of_string a.(0) (* resource_id *)
            in
            let matching_resources = (map res get_one_resource) in 
            let itv_cts = ints2intervals matching_resources in
              Hashtbl.add constraints sql_cts itv_cts;
              itv_cts
          end  
  in 
  let query = Printf.sprintf "
    SELECT jobs.job_id, moldable_job_descriptions.moldable_walltime, jobs.properties,
        moldable_job_descriptions.moldable_id,  
        job_resource_descriptions.res_job_resource_type,
        job_resource_descriptions.res_job_value,
        job_resource_descriptions.res_job_order, 	
        job_resource_groups.res_group_property  
    FROM moldable_job_descriptions, job_resource_groups, job_resource_descriptions, jobs
    WHERE
      moldable_job_descriptions.moldable_index = 'CURRENT'
      AND job_resource_groups.res_group_index = 'CURRENT'
      AND job_resource_descriptions.res_job_index = 'CURRENT'
      AND jobs.state = 'Waiting'
      AND jobs.queue_name =  '%s'
      AND jobs.reservation = 'None'
      AND jobs.job_id = moldable_job_descriptions.moldable_job_id
      AND job_resource_groups.res_group_index = 'CURRENT'
      AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
      AND job_resource_descriptions.res_job_index = 'CURRENT'
      AND job_resource_descriptions.res_job_group_id = job_resource_groups.res_group_id
      ORDER BY moldable_job_descriptions.moldable_id, job_resource_groups.res_group_id, job_resource_descriptions.res_job_order ASC;"
    queue in
  let res = execQuery dbh query in 

  let get_one_row a = ( 
    NoN int_of_string a.(0), (* job_id *) 
    (if flag_besteffort then besteffort_duration else 
      NoN Int64.of_string a.(1)), (* moldable_walltime *)
      NoN int_of_string a.(3), (* moldable_id *)
      NoNStr a.(2),(* properties *)
      NoNStr a.(4), (* res_job_resource_type *)
      NoN int_of_string a.(5), (* res_job_value *)
      NoN int_of_string a.(6), (* res_job_order *)
      NoNStr a.(7) (* res_group_property *)
  )

  in let result = map res get_one_row in

  let rec scan_res res_query prev_job r_o r_t r_v cts jids = match res_query with
      [] -> begin
              (* complete previous job *)
              prev_job.hy_level_rqt <- r_t;
              prev_job.hy_nb_rqt <- r_v;
              prev_job.constraints <- cts;
              (* add job to hashtable *)
              Hashtbl.add jobs prev_job.jobid prev_job;
              (List.rev jids, jobs) (* return list of job_ids jobs' hashtable *)
            end 
      | row::m ->
                let (j_id,j_walltime, j_moldable_id, properties, r_type, r_value, r_order, r_properties) = row in
                if (prev_job.jobid != j_id) then (* next job *)
                  begin
                    (* complete prev job *)
                    if (prev_job.jobid !=0) then 
                      begin
                        prev_job.hy_level_rqt <- List.rev r_t;
                        prev_job.hy_nb_rqt <- List.rev r_v;
                        prev_job.constraints <- List.rev cts;
                       
         (*               Printf.printf "jobs: %s\n" (job_to_string prev_job);   *)
                        Hashtbl.add jobs prev_job.jobid prev_job
                      end;
                    (* prepare next job *)
                    let j = {
                          jobid = j_id;
                          moldable_id = j_moldable_id;
                          time_b = Int64.zero;
                          walltime = j_walltime;
                          types = [];
                          constraints = [];
                          hy_level_rqt = [];
                          hy_nb_rqt = [];
                          set_of_rs = [];
                      } in
                    scan_res m j r_order [[r_type]] [[r_value]] [(get_constraints properties r_properties)] (j_id::jids)
                  end                    
                else
                  begin (* same job *)
                    if r_order = 0 then  (*new resource request*)
                      scan_res m prev_job r_order ([r_type]::r_t) ([r_value]::r_v) ((get_constraints properties r_properties)::cts) jids
    
                    else (*one hierarchy requirement to resource request*)
                      scan_res m prev_job r_order (((List.hd r_t) @ [r_type])::(List.tl r_t))
                                           (((List.hd r_v) @ [r_value])::(List.tl r_v))
                                           cts
                                           jids
                  end
  in  scan_res result {jobid=0;moldable_id =0;time_b=Int64.zero;walltime=Int64.zero;
                      types=[];constraints=[];hy_level_rqt=[];hy_nb_rqt=[];
                      set_of_rs =[];} 
               0 [] [] [] [];; 


(*                                                                *)
(* get_scheduled_jobs: retreive already previously scheduled jobs *)
(* iolib::get_gantt_scheduled_jobs in perl version                *)
(* TODO Remove used field in query ??? *)

let get_scheduled_jobs dbh =
   let query = "SELECT j.job_id, g2.start_time, m.moldable_walltime, g1.resource_id, j.queue_name, j.state, j.job_user, j.job_name,m.moldable_id,j.suspended
      FROM gantt_jobs_resources g1, gantt_jobs_predictions g2, moldable_job_descriptions m, jobs j
      WHERE
        m.moldable_index = 'CURRENT'
        AND g1.moldable_job_id = g2.moldable_job_id
        AND m.moldable_id = g2.moldable_job_id
        AND j.job_id = m.moldable_job_id
      ORDER BY j.start_time, j.job_id;" in
  let res = execQuery dbh query in
(* let first_res = fetch res *)
    let first_res = function
      | None -> []
      | Some first_job -> 
 (*   if not (first_res = None) then *)
          let newjob_res a = 
(* function
           | None -> failwith "pas glop" (*not reacheable*) 
           | Some job_res -> *)
              let j_id = NoN int_of_string a.(0) (* job_id *)
              and j_walltime = NoN Int64.of_string a.(2) (* moldable_walltime *)
              and j_moldable_id = NoN int_of_string a.(8)  (* moldable_id *)
              and j_start_time = NoN Int64.of_string a.(1) (* start_time *)
              and j_nb_res = NoN int_of_string a.(3) in (*resource_id *)  
            
                ( {
                  jobid = j_id;
                  moldable_id = j_moldable_id;
	                time_b = j_start_time;
	                walltime = j_walltime;
                  types = [];
                  constraints = []; (* constraints irrelevant fortest_container already scheduled job *)
                  hy_level_rqt = [];(* // *)
                  hy_nb_rqt = []; (* // *)
                  set_of_rs = []; (* will be set when all resource_id are fetched *)
                }, 
                  [j_nb_res]) 
       in

        let get_job_res a =
          let j_id = NoN int_of_string a.(0) (* job_id *)
          and j_nb_res =  NoN int_of_string a.(3) in (*resource_id *)
          (j_id, j_nb_res)
        in 
      
      let rec aux result job_l current_job_res = match result with
        | None ->   let job = fst current_job_res in 
                      job.set_of_rs <- ints2intervals (snd current_job_res);
                      List.rev (job::job_l) 
        | Some x -> let j_r = get_job_res x in 
                    let j_current = fst current_job_res in
                      if ((fst j_r) = j_current.jobid) then
                        begin 
                          aux (fetch res) job_l (j_current, (snd j_r) :: (snd current_job_res))
                        end 
                      else
                        begin
                          j_current.set_of_rs <- ints2intervals (snd current_job_res); 
                          aux (fetch res) (j_current::job_l) (newjob_res x)
                        end
        in
          aux (fetch res) [] (newjob_res first_job) 
    in
      first_res (fetch res)
 

(* NOT USED only ONE job see save_assignS to job list assignement*)
let save_assign dbh job =
  let moldable_job_id = string_of_int job.moldable_id in 
    let  moldable_job_id_start_time j = 
(*      Printf.sprintf "(%s, %s)" moldable_job_id  (Int64.to_string j.time_b) in *)
      "(" ^ moldable_job_id ^ "," ^ (Int64.to_string j.time_b) ^ ")" in
    let query_pred = 
      "INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ (moldable_job_id_start_time job) in

(*  ignore (execQuery conn query_pred) *)
 
      let resource_to_value res_id = 
	      (* Printf.sprintf "(%s, %s)" moldable_job_id (ml2int res_id) in *)
        "(" ^ moldable_job_id ^ "," ^ (string_of_int res_id ) ^ ")" in

	    let query_job_resources =
      "INSERT INTO  gantt_jobs_resources (moldable_job_id,resource_id) VALUES "^
     	(String.concat ", " (List.map resource_to_value (intervals2ints job.set_of_rs))) 
    in
(*
      Conf.log query_pred;
      Conf.log query_job_resources;
*)
      ignore (execQuery dbh query_pred);
      ignore (execQuery dbh query_job_resources)

let save_assigns conn jobs = (* TODO  ???*)
  let  moldable_job_id_start_time j =
    (* Printf.sprintf "(%s, %s)" (ml2int j.moldable_id) (ml642int j.time_b) in *)
    "(" ^ (string_of_int j.moldable_id) ^ "," ^ (Int64.to_string j.time_b) ^ ")" in

  let query_pred = 
    "INSERT INTO  gantt_jobs_predictions  (moldable_job_id,start_time) VALUES "^ 
     (String.concat ", " (List.map moldable_job_id_start_time jobs)) in

(*  ignore (execQuery conn query_pred) *)
 
    let job_resource_to_value j =
      let moldable_id = string_of_int j.moldable_id in 
      let resource_to_value res = 
	      (* Printf.sprintf "(%s, %s)" moldable_id (ml2int res) in *)
        "(" ^ moldable_id ^ "," ^ (string_of_int res) ^ ")" in
        String.concat ", " (List.map resource_to_value (intervals2ints j.set_of_rs)) in 

	    let query_job_resources =
      "INSERT INTO  gantt_jobs_resources (moldable_job_id,resource_id) VALUES "^
     	(String.concat ",\n " (List.map job_resource_to_value jobs)) 
    in
(*
      Conf.log query_pred;
      Conf.log query_job_resources;
*)
      ignore (execQuery conn query_pred);
      ignore (execQuery conn query_job_resources)

(*                                                  *)
(** retreive job_type for all jobs in the hashtable *)
(*                                                  *)
let get_job_types dbh job_ids h_jobs =  
  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  let query = "SELECT job_id, type FROM job_types WHERE types_index = 'CURRENT' AND job_id IN (" ^ job_ids_str ^ ");" in
  
  let res = execQuery dbh query in
   let add_id_types a = 
      let job = try Hashtbl.find h_jobs ( NoN int_of_string a.(0)) (* job_id *)
        with Not_found -> failwith "get_job_type error can't find job_id" in
        let jt0 = Helpers.split "=" (NoNStr a.(1)) in (* type *)

        let jt = if ((List.length jt0) = 1) then (List.hd jt0)::[""] else jt0 in  
        job.types <- ((List.hd jt), (List.nth jt 1))::job.types in
          ignore (map res add_id_types);;

(*                                                                            *)
(* TODO factorize with get_job_types ?? change simple_cbf**.ml ??? REMOVE ??? *)
(*                                                                            *)
let get_job_types_hash_ids dbh jobs =
  let h_jobs =  Hashtbl.create 1000 in
  let job_ids = List.map (fun n -> Hashtbl.add h_jobs n.jobid n; n.jobid) jobs in 
  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  
  let query = "SELECT job_id, type FROM job_types WHERE types_index = 'CURRENT' AND job_id IN (" ^ job_ids_str ^ ");" in
  
  let res = execQuery dbh query in
    let add_id_types a =
      let job = try Hashtbl.find h_jobs (NoN int_of_string a.(0)) (* job_id *)
        with Not_found -> failwith "get_job_type error can't find job_id" in
        let jt0 = Helpers.split "=" (NoNStr a.(1)) in (* type *)

        let jt = if ((List.length jt0) = 1) then (List.hd jt0)::[""] else jt0 in 
        job.types <- ((List.hd jt), (List.nth jt 1))::job.types in
          ignore (map res add_id_types);
          (h_jobs, job_ids);;

(* retrieve jobs dependencies *)
(* return an hashtable, key = job_id, value = list of required jobs *)
let get_current_jobs_dependencies dbh =
  let h_jobs_dependencies =  Hashtbl.create 100 in
  let query = "SELECT job_id, job_id_required FROM job_dependencies WHERE job_dependency_index = 'CURRENT'" in
  let res = execQuery dbh query in
  let get_one a =
    let job_id = NoN int_of_string a.(0) in (* job_id *)
    let job_id_required = NoN int_of_string a.(1) in (* job_id_required *)

    let dependencies = try Hashtbl.find h_jobs_dependencies job_id with Not_found -> (Hashtbl.add h_jobs_dependencies job_id []; []) in
    Hashtbl.replace h_jobs_dependencies job_id (job_id_required::dependencies) in
      ignore (map res get_one);
      h_jobs_dependencies;;

(*                                                                         *)
(* retrieve status of required jobs of jobs with dependencies              *)
(* return an hashtable, key = job_id, value = list of required jobs_status *)

let get_current_jobs_required_status dbh =
  let h_jobs_required_status =  Hashtbl.create 100 in

(* TODO to simplify ??? / remove unsed fields *)
  let query = " SELECT jobs.job_id, jobs.state, jobs.job_type, jobs.exit_code, jobs.start_time, moldable_job_descriptions.moldable_walltime
                FROM jobs,job_dependencies, moldable_job_descriptions
                WHERE job_dependencies.job_dependency_index = 'CURRENT' 
                AND jobs.job_id = job_dependencies.job_id_required
                AND jobs.job_id = moldable_job_descriptions.moldable_job_id
                GROUP BY jobs.job_id;" in
  let res = execQuery dbh query in
  let get_one a =
    let j_id = NoN int_of_string a.(0) (* job_id *) 
    and j_state = NoNStr a.(1) (* state *)
    and j_jtype = NoNStr a.(2) (* job_type *)
    and j_exit_code = NoN int_of_string a.(3) (* exit_code *)

(*
    and j_start_time = not_null int642ml (get "start_time")
    and j_walltime = not_null int642ml (get "moldable_walltime")
*)
      in (j_id, {
(*                  jr_id = j_id; *)
                  jr_state = j_state;
                  jr_jtype = j_jtype;
                  jr_exit_code = j_exit_code;
(*
                  jr_start_time = j_start_time;
                  jr_walltime = j_walltime;
*)
                })
    in 
    let results = map res get_one in
      ignore ( List.iter (fun x -> Hashtbl.add h_jobs_required_status (fst x) (snd x) ) results);
      h_jobs_required_status;;
(*    
 set_job_message
 sets the message field of the job of id passed in parameter
 parameters : dbh, job_id, message
 return value : /
 side effects : changes the field message of the job in the table Jobs
*)
let set_job_message dbh job_id message = 
  let query =  Printf.sprintf "UPDATE jobs SET message = '%s' WHERE job_id = %d" message job_id in
    ignore (execQuery dbh query)

(*
  set_job_scheduler_info
  sets the scheduler_info field of the job of id passed in parameter
  parameters : dbh, job_id, message
  return value : /
*)
let set_job_scheduler_info dbh job_id message = 
  let query =  Printf.sprintf "UPDATE jobs SET scheduler_info = '%s' WHERE job_id = %d" message job_id in
    ignore (execQuery dbh query)

let set_job_and_scheduler_message dbh job_id message =  
  let query =  Printf.sprintf "UPDATE jobs SET  message = '%s', scheduler_info = '%s',   WHERE job_id = %d" message message job_id in
    ignore (execQuery dbh query)

let set_job_and_scheduler_message_range dbh job_ids message =
  let job_ids_str = Helpers.concatene_sep "," string_of_int job_ids in
  let query =  Printf.sprintf "UPDATE jobs SET  message = '%s', scheduler_info = '%s',   WHERE IN ('%s');" message message job_ids_str in
    ignore (execQuery dbh query)

