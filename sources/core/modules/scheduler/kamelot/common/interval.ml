(* todo *)
(* suppress the result list in inter_interval list argument !!! *) 
(* need to propage in all directory !!! *)
(* interval is the basic unit to construct set of resources *)
type interval = {b : int; e : int}
type set_of_resources = interval list

(* Convert interval to string*)
let itv2str itv = Printf.sprintf "{b:%d,e:%d}" itv.b itv.e;;
(* Convert list of interval to string*)
let itvs2str itvs = "["^(String.concat ", " (List.map itv2str itvs))^"]";; 
(* Convert array of interval to string*)
let itva2str itva = "[|"^(String.concat ", " (List.map itv2str (Array.to_list itva)))^"|]" ;;

(* generate list of intervals from list of unordered ints with greedy approach *)
(* must be quicker with a dichotomic approach in most cases *)
let ints2intervals ints =   
	let ordered_ints = List.sort Pervasives.compare ints in 
		let rec aux list_int itv_b prev itvs = match list_int with
      | [] ->  [{b=itv_b; e=itv_b}]
			| x::[] ->  if x > (prev+1) then
										List.rev ({b=x; e=x}::{b=itv_b; e=prev}::itvs)
									else
										List.rev ({b=itv_b; e=x}::itvs)
			| x::n -> if x > (prev+1) then
								  aux n x x ({b=itv_b; e=prev}::itvs)
					 			else
									aux n itv_b x itvs
			in
		aux (List.tl ordered_ints) (List.hd ordered_ints) (List.hd ordered_ints) [];;
(*
# ints2intervals [];;  WARNING TO MODIFY ????
Exception: Failure "hd".
#  ints2intervals [2];;
- : interval list = [{b = 2; e = 2}]
# ints2intervals [2;4;1;3];;
- : interval list = [{b = 1; e = 4}]
# ints2intervals [2;4;1;];;
- : interval list = [{b = 1; e = 2}; {b = 4; e = 4}]
#  ints2intervals [2;4];;
- : interval list = [{b = 2; e = 2}; {b = 4; e = 4}]
# ints2intervals [4;5;7;1;2;3;6;9;8];;
- : interval list = [{b = 1; e = 9}]
*)

(* generate list of ints from list of intervals *)

let intervals2ints itv_l =
  let rec aux itvs ints = match itvs with
    | [] -> ints
    | x::n ->   let rec loop up_ints rid i =
                  if i<0 then
                    aux n up_ints
                  else
                    loop (rid::up_ints) (rid+1) (i-1)
                in
                loop ints x.b (x.e-x.b)
  in
  aux itv_l [];;
(*
# intervals2ints  [{b = 1; e = 4}];;
- : int list = [4; 3; 2; 1]
# intervals2ints [{b = 2; e = 2}; {b = 4; e = 4}]
  ;;
- : int list = [2; 4]
# intervals2ints [{b = 1; e = 2}; {b = 4; e = 4}]
  ;;
- : int list = [2; 1; 4]
*)

(*                                              *)
(* compute intersection of 2 resource intervals *)
(*                                              *)
let inter_intervals itv1s itv2s =
  let rec inter_itvs itv_l_1 itv_l_2 itv_l_inter = 
	  match (itv_l_1,itv_l_2) with
	    | (x::n,y::m) ->
			  if (y.e < x.b) then inter_itvs (x::n) m itv_l_inter else (* y before x w/ no overlap *)
			  if (y.b > x.e) then inter_itvs n (y::m) itv_l_inter else (* x before y w/ no overlap *)
			  if (y.b >= x.b) then 
				  if (y.e <=  x.e) then  (* y before y w/ no overlap *)
					  inter_itvs ({b=y.e+1;e=x.e}::n) m ({b=y.b;e=y.e}::itv_l_inter)
				  else 
					  inter_itvs n ({b=x.e+1;e=y.e}::m) ({b=y.b;e=x.e}::itv_l_inter)
			  else
				  if (y.e <=  x.e) then
					  inter_itvs ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.e}::itv_l_inter)
				  else
					  inter_itvs n ({b=x.e+1;e=y.e}::m) ({b=x.b;e=x.e}::itv_l_inter)
	  | (_,_) -> List.rev itv_l_inter
    in
      inter_itvs itv1s itv2s [];;

(*                                               *)
(* compute intersection of 2 intervals resources *)
(* with resources counter nb_res                 *)
(*                                               *)
let inter_intervals_n itv1s itv2s = 
  let rec inter_itvs_n itv_l_1 itv_l_2 itv_l_inter nb_res = 
	  match (itv_l_1,itv_l_2) with
	  | (x::n,y::m) ->
		  	if (y.e < x.b) then inter_itvs_n (x::n) m itv_l_inter nb_res else (* y before x w/ no overlap *)
			  if (y.b > x.e) then inter_itvs_n n (y::m) itv_l_inter nb_res else (* x before y w/ no overlap *)
			  if (y.b >= x.b) then
				  if (y.e <=  x.e) then  (* y before y w/ no overlap *)
					  inter_itvs_n ({b=y.e+1;e=x.e}::n) m ({b=y.b;e=y.e}::itv_l_inter) (nb_res + y.e - y.b + 1)
				  else 
					  inter_itvs_n n ({b=x.e+1;e=y.e}::m) ({b=y.b;e=x.e}::itv_l_inter) (nb_res + x.e - y.b + 1)
			  else
				  if (y.e <=  x.e) then
					  inter_itvs_n ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.e}::itv_l_inter) (nb_res + y.e - x.b + 1)
				  else
					  inter_itvs_n n ({b=x.e+1;e=y.e}::m) ({b=x.b;e=x.e}::itv_l_inter) (nb_res + x.e - x.b + 1)
	  | (_,_) -> (List.rev itv_l_inter,nb_res)
  in
    inter_itvs_n itv1s itv2s [] 0;;

(*
let x1 = {b = 11; e = 20};; 
let y1 =  {b = 1; e = 5};; 
let y2 =  {b = 26; e = 30};;

let y3 =  {b = 12; e = 15};; 
let y4 =  {b = 12; e = 25};; 
let y5 =  {b = 5; e = 15};; 
let y6 =  {b = 5; e = 25};; 

let x2 = [{b = 1; e = 2}; {b = 5; e = 5}] 

let yl1 = [{b = 5; e = 13};{b = 15; e = 16 };{b = 19; e = 19}];;

inter_intervals [x1] [y1] [];; (* [] *)
inter_intervals [x1] [y2] [];; (* [] *)
inter_intervals [x1] [y3] [];; (* [{b = 12; e = 15}] *)
inter_intervals [x1] [y4] [];; (* [{b = 12; e = 20}] *)
inter_intervals [x1] [y5] [];; (* [{b = 11; e = 15}] *)
inter_intervals [x1] [y6] [];; (* [{b = 11; e = 20}] *)
inter_intervals [x1] [y7] [];; (* [{b = 11; e = 20}] *)

inter_intervals_0 [x1] yl1 [];;(* *)

inter_intervals [x1] [y1] [] 0;; (* [] *)
inter_intervals [x1] [y2] [] 0;; (* [] *)
inter_intervals [x1] [y3] [] 0;; (* [{b = 12; e = 15}] *)
inter_intervals [x1] [y4] [] 0;; (* [{b = 12; e = 20}] *)
inter_intervals [x1] [y5] [] 0;; (* [{b = 11; e = 15}] *)
inter_intervals [x1] [y6] [] 0;; (* [{b = 11; e = 20}] *)
inter_intervals [x1] [y7] [] 0;; (* [{b = 11; e = 20}] *)

inter_intervals [x1] yl1 [] 0;;(* ([{b = 11; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}], 6) *)
*)

(* some converter to string *)
let itv2str itv   = Printf.sprintf "{%d,%d}" itv.b itv.e ;; 
let itvs2str itvs = "["^(String.concat ", " (List.map itv2str itvs))^"]" ;;
let itva2str itva = "[|"^(String.concat ", " (List.map itv2str (Array.to_list itva)))^"|]" ;;

(*                                              *)
(* compute substraction of 2 resource intervals *)
(*                                              *)
let sub_intervals_orig x_l y_l = 
	let rec sub_interval_l itv_l_1 itv_l_2 sub_itv_l = 
		match (itv_l_1,itv_l_2) with
		| (x::n,y::m) ->
				if (y.e < x.b) then sub_interval_l (x::n) m sub_itv_l else (* y before x w/ no overlap *)
				if (y.b > x.e) then sub_interval_l n (y::m) (sub_itv_l @ [x]) else (* x before y w/ no overlap *)
				if (y.b > x.b) then 
					if (y.e <  x.e) then  (* y before y w/ no overlap *)
						sub_interval_l ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.b-1}::sub_itv_l)
					else 
						sub_interval_l n (y::m) ({b=x.b;e=y.b-1}::sub_itv_l)
				else
					if (y.e <  x.e) then
						sub_interval_l ({b=y.e+1;e=x.e}::n) m sub_itv_l
					else
						sub_interval_l n (y::m) sub_itv_l
		| (x_l,[]) ->  (List.rev sub_itv_l) @ x_l
		| (_,_) -> List.rev sub_itv_l

	in  sub_interval_l x_l y_l [];;


(*                                              *)
(* compute addition of 2 resource intervals *)
(*                                              *)
let add_intervals itv1_l itv2_l  = 
  let rec add_itvs itv1s itv2s accu_itvs = match (itv1s, itv2s) with
      ([],[]) -> List.rev accu_itvs
    | (x,[]) -> (List.rev accu_itvs) @ x
    | ([],y) -> (List.rev accu_itvs) @ y 
    | (x::n,y::m) ->
      if (y.e < x.b) then add_itvs (x::n) m (y::accu_itvs) else (* y before x w/ no overlap -> add y *)
      if (y.b > x.e) then add_itvs n (y::m) (x::accu_itvs) else (* x before y w/ no overlap -> add x *)
      if (y.b > x.b) then (* x begin *)
        if (y.e <  x.e) then
          add_itvs (x::n) m accu_itvs (* x overlap totally y -> keep x and drop y *)
        else 
          add_itvs n ({b=x.b;e=y.e}::m) accu_itvs (* x began by overlap y and y overlop x at the end -> keep x.b y.e on y and remove x  *)
      else (*  *) (* y begin *) 
      if (y.e <  x.e) then (* y began by overlap x and x overlap y at the end -> keep y.b x.e on x and remove y *)
          add_itvs ({b=y.b;e=x.e}::n) m accu_itvs
        else
          add_itvs n (y::m) accu_itvs (* y overlap totally x -> keep y and drop x *)

    in add_itvs itv1_l itv2_l []
(*
add_intervals [x1] [y1] ;; [x1;y1]
add_intervals [x1] [y2] ;; [{b = 11; e = 20}; {b = 26; e = 30}]
add_intervals [x1] [y3] ;; [{b = 11; e = 20}]
add_intervals [x1] [y4] ;; [{b = 11; e = 25}]
add_intervals [x1] [y5] ;; [{b = 5; e = 20}]
add_intervals [x1] [y6] ;; [{b = 5; e = 25}]
add_intervals [x1] [x1] ;; [x1]
add_intervals [x1] [];; [x1]
add_intervals [x1] yl1 ;; [{b = 5; e = 20}]
add_intervals [y5] [x1];;

add_intervals x2 [y3];; [{b = 1; e = 2}; {b = 5; e = 5}; {b = 12; e = 15}]
*)



(*                                              *)
(* compute substraction of 2 resource intervals *)
(*                                              *)
let sub_intervals x_l y_l = 
	let rec sub_interval_l itv_l_1 itv_l_2 sub_itv_l = 
		match (itv_l_1,itv_l_2) with
		| (x::n,y::m) ->
				if (y.e < x.b) then sub_interval_l (x::n) m sub_itv_l else (* y before x w/ no overlap *)
				if (y.b > x.e) then sub_interval_l n (y::m) (x::sub_itv_l) else (* x before y w/ no overlap *)
				if (y.b > x.b) then 
					if (y.e <  x.e) then  (* x overlap totaly y*)
						sub_interval_l ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.b-1}::sub_itv_l) (* x overlap totally y*)
					else 
						sub_interval_l n (y::m) ({b=x.b;e=y.b-1}::sub_itv_l) (* x overlap partially y*)
				else
					if (y.e <  x.e) then
						sub_interval_l ({b=y.e+1;e=x.e}::n) m sub_itv_l
					else
						sub_interval_l n (y::m) sub_itv_l
		| (x_l,[]) ->  (List.rev sub_itv_l) @ x_l
		| (_,_) -> List.rev sub_itv_l

	in  sub_interval_l x_l y_l [];;

(* sub_intervals [{b = 1; e = 5}] [{b = 3; e = 4}; {b = 12; e = 12}];; *)

(*
sub_intervals [x1] [y1] ;; [x1]
sub_intervals [x1] [y2] ;; [x1]
sub_intervals [x1] [y3] ;; [{b = 11; e = 11}; {b = 16; e = 20}]
sub_intervals [x1] [y4] ;; [{b = 11; e = 11}]
sub_intervals [x1] [y5] ;; [{b = 16; e = 20}]
sub_intervals [x1] [y6] ;; []
sub_intervals [x1] [x1] ;; []
sub_intervals [x1] [];; [x1]
sub_intervals [x1] yl1 ;;  [{b = 14; e = 14}; {b = 17; e = 18}; {b = 20; e = 20}]
sub_intervals [y5] [x1];;  [{b = 5; e = 10}]

sub_intervals x2 [y3];; [{b = 1; e = 2}; {b = 5; e = 5}]

*)

(*                              *)
(* Intervals comparaison        *)
(* Compare function is suitable *)
(*                              *)
let itvs_compare = compare
(* 
# compare {b = 1; e = 7} {b = 41; e =47 } ;;
- : int = -1
# compare  {b = 41; e =47 } {b = 1; e = 7} ;;
- : int = 1
# compare  {b = 1; e =47 } {b = 1; e = 7} ;;
- : int = 1
# compare  {b = 1; e =7 } {b = 1; e = 47};;
- : int = -1
# compare  {b = 1; e =7 } {b = 1; e = 7};;
- : int = 0
*)

(* return [] *)
(* itv_l_a itv_l_reference  MUST BE ORDERED by ascending resource id *)

(* Is it use ?*)


(*                                                        *)
(* Extract n block from itv_l_reference inclued initv_l_a *)
(*                                                        *)
let extract_n_block_itv itv_l_a itv_l_reference n =
  let itv_l_seg = inter_intervals itv_l_a itv_l_reference in
  let rec extract_n_itv itv_l_1 itv_l_ref itv_l_result nb_itv = match (itv_l_1,itv_l_ref) with
    | ([],_) | (_,[]) -> [] 
    | (x::n,y::m) -> if x=y then
                       if nb_itv=1 then
                         List.rev (x::itv_l_result) 
                       else
                         extract_n_itv n m (x::itv_l_result) (nb_itv -1)  
                     else
                       if y.e < x.b then
                         extract_n_itv (x::n) m itv_l_result nb_itv
                       else 
                         if x.e < y.e then 
                           extract_n_itv n (y::m) itv_l_result nb_itv
                         else
                           extract_n_itv n m itv_l_result nb_itv
  in extract_n_itv itv_l_seg itv_l_reference [] n;;

(*
let y = [{b = 5; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}]
#  extract_n_block_itv y y 1 ;;
- : interval list = [{b = 5; e = 13}]
#  extract_n_block_itv y y 2 ;;
- : interval list = [{b = 5; e = 13}; {b = 15; e = 16}]
#  extract_n_block_itv y y 3 ;;
- : interval list = [{b = 5; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}]
#  extract_n_block_itv [{b = 15; e = 16}; {b = 19; e = 19}] y 3 ;;
- : interval list = []
#  extract_n_block_itv [{b = 15; e = 16}; {b = 19; e = 19}] y 2 ;;
- : interval list = [{b = 15; e = 16}; {b = 19; e = 19}]
#  extract_n_block_itv [{b = 15; e = 16}; {b = 19; e = 19}] y 2 ;;
- : interval list = [{b = 15; e = 16}; {b = 19; e = 19}]

*)
 
(*                                                                                           *)
(* test if a list of intervals if a prefix of another list of instervals and substract prefix *)
(*                                                                                           *)
let test_and_sub_prefix_itvs prefix_itvs (lst_itvs: interval list)  =
(*
    Printf.printf "prefix %s \n"  (itvs2str prefix_itvs);
    Printf.printf "lst_itvs %s \n" (itvs2str lst_itvs);
*)
    let rec next_prefix prefixes itvs = match (prefixes, itvs) with
      | ([],residue_itvs) -> (true, residue_itvs)      
      | (x::m,y::n) -> if x=y then
                          next_prefix m n
                       else
                          (false, sub_intervals (y::n) (prefixes) )
      | (x,[]) -> (false, [])
    in
       next_prefix prefix_itvs lst_itvs;;

(*
# let y = [{b = 5; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}]
# test_and_sub_prefix_itvs y y
- : bool * Interval.interval list = (true, [])
# test_and_sub_prefix_itvs [{b = 5; e = 13}; {b = 14; e = 14}] y;;
- : bool * Interval.interval list = (false, [{b = 15; e = 16}; {b = 19; e = 19}])
# test_and_sub_prefix_itvs y [{b = 5; e = 13}; {b = 15; e = 16}];;
- : bool * Interval.interval list = (false, [])
# test_and_sub_prefix_itvs [{b=1;e=4}; {b=6;e=9}] [{b=6;e=9}; {b=10;e=17}; {b=20;e=30}];;
(false, [{b = 10; e = 17}; {b = 20; e = 30}])
*)

(*                                                                  *)
(* Extract n scattered block from itv_l_reference inclued initv_l_a *)
(* scattered blocks come from ordered resources in hierarchy        *)
(*                                                                  *)

let extract_n_scattered_block_itv (itv_l_a: interval list) (lst_itvs_reference: interval list list)  n =
(*
  let sorted_itvs = List.fast_sort itvs_compare (List.flatten lst_itvs_reference) in
  let itvs_seg = inter_intervals itv_l_a sorted_itvs in
*)
  (* TODO optimize ???*)
  let itvs_seg = List.flatten (List.map (fun x -> inter_intervals x itv_l_a) lst_itvs_reference) in (* TODO optimize !!! *)
  let rec extract_n_itv residual_itvs_seg lst_itvs_ref itvs_result nb_bk = match lst_itvs_ref with
    | [] -> [] 
    | x::m -> let test_prefix, residual_itvs = test_and_sub_prefix_itvs x residual_itvs_seg in
              if test_prefix then
                  if nb_bk=1 then
                    (* List.rev ((List.rev x)@itvs_result) *)
                    List.fast_sort itvs_compare (x@itvs_result)
                  else
                    (* extract_n_itv residual_itvs m ((List.rev x)@itvs_result) (nb_bk-1) *)
                    extract_n_itv residual_itvs m (x@itvs_result) (nb_bk-1) 
              else
                 extract_n_itv residual_itvs m itvs_result nb_bk
  in extract_n_itv itvs_seg lst_itvs_reference [] n;;

(*
# let y = [[{b = 1; e = 4}; {b = 6; e = 9};]; [{b = 10; e = 17}]; [{b = 20; e = 30}]];;
#  extract_n_scattered_block_itv [{b = 1; e = 30}] y 3;;
[{b = 1; e = 4}; {b = 6; e = 9}; {b = 10; e = 17}; {b = 20; e = 30}]
 extract_n_scattered_block_itv [{b = 1; e = 12}; {b = 15; e = 32}] y 2;;
[{b = 1; e = 4}; {b = 6; e = 9}; {b = 20; e = 30}]

#  extract_n_scattered_block_itv [{b = 6; e = 30}] y 1;;
- : Interval.interval list = [{b = 10; e = 17}]


let h01 = [[{b = 1; e = 7};{b = 41; e =47 }];[{b = 17; e = 32}]];;
# extract_n_scattered_block_itv  [{b = 1; e = 50}] h01 1;;
- : Interval.interval list = [{b = 1; e = 7}; {b = 41; e = 47}]

# extract_n_scattered_block_itv  [{b = 1; e = 50}] h01 2;;
- : Interval.interval list = [{b = 1; e = 7}; {b = 17; e = 32}; {b = 41; e = 47}]

*)

(*                                                                                 *)
(* Extract maximum number scattered blocks from itv_l_reference inclued initv_l_a  *)
(* scattered blocks come from ordered resources in hierarchy                       *)
(* Used for BEST resource request                                                  *)
let extract_max_scattered_block_itv (itv_l_a: interval list) (lst_itvs_reference: interval list list) =
  (* TODO optimize ???*)
  let itvs_seg = List.flatten (List.map (fun x -> inter_intervals x itv_l_a) lst_itvs_reference) in (* TODO optimize !!! *)
  let rec extract_n_itv residual_itvs_seg lst_itvs_ref itvs_result nb_bk = match lst_itvs_ref with
    | [] -> (List.fast_sort itvs_compare itvs_result, nb_bk)
    | x::m -> let test_prefix, residual_itvs = test_and_sub_prefix_itvs x residual_itvs_seg in
              if test_prefix then
                extract_n_itv residual_itvs m (x@itvs_result) (nb_bk+1) 
              else
                extract_n_itv residual_itvs m itvs_result nb_bk
  in extract_n_itv itvs_seg lst_itvs_reference [] 0;;

(*
# let y = [[{b = 1; e = 4}; {b = 6; e = 9};]; [{b = 10; e = 17}]; [{b = 20; e = 30}]];;
val y : Interval.interval list list =
  [[{b = 1; e = 4}; {b = 6; e = 9}]; [{b = 10; e = 17}]; [{b = 20; e = 30}]]
# extract_all_scattered_block_itv [{b = 1; e = 29}] y 0;;
- : Interval.interval list * int =
([{b = 1; e = 4}; {b = 6; e = 9}; {b = 10; e = 17}], 2)

*)

(*                                                                       *)
(* Extract all  scattered blocks from itv_l_reference inclued initv_l_a  *)
(* scattered blocks come from ordered resources in hierarchy             *)
(* ALL                                                                   *)
let extract_all_scattered_block_itv (itv_l_a: interval list) (lst_itvs_reference: interval list list) =
  let itvs_seg = List.flatten (List.map (fun x -> inter_intervals x itv_l_a) lst_itvs_reference) in (* TODO optimize !!! *)
  let rec extract_n_itv residual_itvs_seg lst_itvs_ref itvs_result = match lst_itvs_ref with
    | [] -> List.fast_sort itvs_compare itvs_result
    | x::m -> let test_prefix, residual_itvs = test_and_sub_prefix_itvs x residual_itvs_seg in
              if test_prefix then
                extract_n_itv residual_itvs m (x@itvs_result)
              else
                []
  in extract_n_itv itvs_seg lst_itvs_reference [];;

(*                                                                                                *)
(* Extract scattered block from itv_l_reference inclued initv_l_a accordingly to n value          *)
(*  | ALL (-1) -> all blocks of the hierarchy level                                               *)
(*  | BEST (-2) -> all available blocks                                                           *)
(*  | BESTHALF (-3) -> previous nb block divide by 2 (BEST/2), note if BEST=1 then BEST0.5=1 not 0 *)
(* scattered blocks come from ordered resources in hierarchy                                      *)
(*                                                                                                *)
let extract_scattered_block_itv (itv_l_a: interval list) (lst_itvs_reference: interval list list) n = match n with 
 | -1 -> extract_all_scattered_block_itv itv_l_a lst_itvs_reference (* ALL *)
 | -2 -> let res, nb_bk =  extract_max_scattered_block_itv itv_l_a lst_itvs_reference in res (* BEST *)
 | -3 -> let res, nb_bk =  extract_max_scattered_block_itv itv_l_a lst_itvs_reference in     (* BESTHALF -> BEST/2*)
          if nb_bk=1 then
            res
          else
            (* NOTE: is not optimal but we presume that BESTHALF will rarely used *)
            extract_n_scattered_block_itv itv_l_a lst_itvs_reference (nb_bk/2) 
 | _  -> extract_n_scattered_block_itv itv_l_a lst_itvs_reference n
 
(* Is it use ?*)

let extract_block_itv itv_l_a itv_l_reference =
  let itv_l_seg = inter_intervals itv_l_a itv_l_reference  in
  let rec extract_itv itv_l_1 itv_l_ref itv_l_result = match (itv_l_1,itv_l_ref) with
    | (x::n,y::m) -> if x=y then
                       extract_itv n m (x::itv_l_result)
                     else
                       if y.e < x.b then
                         extract_itv (x::n) m itv_l_result
                       else 
                         if x.e < y.e then 
                           extract_itv n (y::m) itv_l_result
                         else
                           extract_itv n m itv_l_result
    |(_,_) -> List.rev itv_l_result
  in extract_itv itv_l_seg itv_l_reference [];;

(* Is it use ?*)
let extract_n_min_block_itv itv_l_a itv_l_reference n =
  let itv_l_seg = inter_intervals itv_l_a itv_l_reference in
  let rec extract_n_min_itv itv_l_1 itv_l_ref itv_l_result nb_itv = match (itv_l_1,itv_l_ref) with
    | (x::n,y::m) -> if x=y then
                       extract_n_min_itv n m (x::itv_l_result) (nb_itv -1)  
                     else
                       if y.e < x.b then
                         extract_n_min_itv (x::n) m itv_l_result nb_itv
                       else 
                         if x.e < y.e then 
                           extract_n_min_itv n (y::m) itv_l_result nb_itv
                         else
                           extract_n_min_itv n m itv_l_result nb_itv
    | (_,_) -> if (nb_itv < 1) then List.rev itv_l_result else []
  in extract_n_min_itv itv_l_seg itv_l_reference [] n;;

(*                                                                                                      *)
(* extract_no_empty_bk : keep no empty intersection interval between  itv_l_a itv_l_reference and itv_l *)
(*                                                                                                      *)

let extract_no_empty_bk itv_l_a itv_l_reference =
 let rec extract_itv itv_l_ref result  = match itv_l_ref with
  | [] -> List.rev result
  | (x::n) -> let inter_itvs = inter_intervals itv_l_a [x] in 
              match inter_itvs with 
                | [] -> extract_itv n result 
                | y -> extract_itv n (x::result)
  in extract_itv itv_l_reference [];;
(*
let a = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b2 = [{b = 1; e = 8}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b3 = [{b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b4 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}];;
let b5 = [{b = 10; e = 12}; {b = 13; e = 14};];;
let b6 = [{b = 3; e = 4}; {b = 19; e = 20};];;

*)
(*                                                                                            *)
(* keep_no_empty_scat_bks : keep no empty scattered blocks where their intersection with itvs is not empty *)
(*                                                                                                         *)
let keep_no_empty_scat_bks itvs (scat_bks: interval list list) =
  Helpers.map_wo_empty (fun scat_bk -> extract_no_empty_bk itvs scat_bk) scat_bks;;
 
(* extract interval list intersect for each reference intervals, also give the nb of non empty intersection*)

let extract_itv_by_itv_nb_inter itv_l_a itv_l_reference =
  let rec extract_itv itv_l_ref result nb_inter = match itv_l_ref with
    | [] -> (List.rev result,nb_inter)
    | (x::n) -> let inter_itvs =  inter_intervals itv_l_a [x] in 
                match inter_itvs with 
                  | [] -> extract_itv n result nb_inter 
                  | y -> extract_itv n (y::result) (nb_inter + 1) 
  in extract_itv itv_l_reference [] 0;;

(*
let a = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b2 = [{b = 1; e = 8}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b3 = [{b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b4 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}];;
let b5 = [{b = 10; e = 12}; {b = 13; e = 14};];;

# extract_itv_by_itv_nb_inter b1 a;;
- : interval list list * int =
([[{b = 1; e = 8}]; [{b = 9; e = 16}]; [{b = 17; e = 24}];
  [{b = 25; e = 32}]],
 4)
# extract_itv_by_itv_nb_inter b2 a;;
- : interval list list * int =
([[{b = 1; e = 8}]; [{b = 17; e = 24}]; [{b = 25; e = 32}]], 3)
# extract_itv_by_itv_nb_inter b3 a;;
- : interval list list * int =
([[{b = 9; e = 16}]; [{b = 17; e = 24}]; [{b = 25; e = 32}]], 3)
# extract_itv_by_itv_nb_inter b4 a;;
- : interval list list * int =
([[{b = 1; e = 8}]; [{b = 9; e = 16}]; [{b = 17; e = 24}]], 3)

# extract_itv_by_itv_nb_inter b5 a;;
- : interval list list * int = ([[{b = 10; e = 12}; {b = 13; e = 14}]], 1)
*)


