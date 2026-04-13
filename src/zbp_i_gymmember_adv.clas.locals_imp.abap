CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    CLASS-DATA: mt_buffer        TYPE STANDARD TABLE OF zgym_members,
                mt_delete_buffer TYPE STANDARD TABLE OF sysuuid_x16.
ENDCLASS.

CLASS lcl_handler DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR GymMember RESULT result.

    METHODS create FOR MODIFY IMPORTING entities FOR CREATE GymMember.
    METHODS update FOR MODIFY IMPORTING entities FOR UPDATE GymMember.
    METHODS delete FOR MODIFY IMPORTING keys FOR DELETE GymMember.
    METHODS read FOR READ IMPORTING keys FOR READ GymMember RESULT result.
    METHODS lock FOR LOCK IMPORTING keys FOR LOCK GymMember.

    METHODS simulateRetention FOR MODIFY
      IMPORTING keys FOR ACTION GymMember~simulateRetention RESULT result.

    METHODS validateAttendance FOR VALIDATE ON SAVE
      IMPORTING keys FOR GymMember~validateAttendance.

    METHODS calculateMemberType FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GymMember~calculateMemberType.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<fs_key>).
      APPEND VALUE #( %tky = <fs_key>-%tky %action-simulateRetention = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD create.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<fs_ent>).
      INSERT CORRESPONDING #( <fs_ent> ) INTO TABLE lcl_buffer=>mt_buffer.
      APPEND VALUE #( %cid = <fs_ent>-%cid member_id = <fs_ent>-member_id ) TO mapped-gymmember.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<fs_ent>).
      READ TABLE lcl_buffer=>mt_buffer WITH KEY member_id = <fs_ent>-member_id ASSIGNING FIELD-SYMBOL(<fs_buf>).
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM zgym_members WHERE member_id = @<fs_ent>-member_id INTO @DATA(ls_db).
        INSERT ls_db INTO TABLE lcl_buffer=>mt_buffer ASSIGNING <fs_buf>.
      ENDIF.
      DATA(ls_upd) = CORRESPONDING zgym_members( <fs_ent> MAPPING FROM ENTITY ).
      IF <fs_ent>-%control-full_name = if_abap_behv=>mk-on. <fs_buf>-full_name = ls_upd-full_name. ENDIF.
      IF <fs_ent>-%control-member_type = if_abap_behv=>mk-on. <fs_buf>-member_type = ls_upd-member_type. ENDIF.
      IF <fs_ent>-%control-attendance_rate = if_abap_behv=>mk-on. <fs_buf>-attendance_rate = ls_upd-attendance_rate. ENDIF.
      IF <fs_ent>-%control-last_visit_days = if_abap_behv=>mk-on. <fs_buf>-last_visit_days = ls_upd-last_visit_days. ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<fs_key>).
      INSERT <fs_key>-member_id INTO TABLE lcl_buffer=>mt_delete_buffer.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<fs_key>).
      READ TABLE lcl_buffer=>mt_buffer WITH KEY member_id = <fs_key>-member_id INTO DATA(ls_mem).
      IF sy-subrc <> 0. SELECT SINGLE * FROM zgym_members WHERE member_id = @<fs_key>-member_id INTO @ls_mem. ENDIF.
      IF ls_mem IS NOT INITIAL. APPEND CORRESPONDING #( ls_mem MAPPING TO ENTITY ) TO result. ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD calculateMemberType.
    READ ENTITIES OF ZI_GymMember_Adv IN LOCAL MODE
      ENTITY GymMember FIELDS ( attendance_rate ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_gym).

    LOOP AT lt_gym ASSIGNING FIELD-SYMBOL(<fs_gym>).
      DATA(lv_type) = COND #( WHEN <fs_gym>-attendance_rate > 80 THEN 'GOLD' ELSE 'SILVER' ).

      MODIFY ENTITIES OF ZI_GymMember_Adv IN LOCAL MODE
        ENTITY GymMember UPDATE FIELDS ( member_type )
        WITH VALUE #( ( %tky = <fs_gym>-%tky member_type = lv_type ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD validateAttendance.
    READ ENTITIES OF ZI_GymMember_Adv IN LOCAL MODE
      ENTITY GymMember FIELDS ( attendance_rate ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_gym).
    LOOP AT lt_gym ASSIGNING FIELD-SYMBOL(<fs_gym>).
      IF <fs_gym>-attendance_rate < 0 OR <fs_gym>-attendance_rate > 100.
        APPEND VALUE #( %tky = <fs_gym>-%tky ) TO failed-gymmember.
        APPEND VALUE #( %tky = <fs_gym>-%tky
                        %msg =  new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                       text     = 'Attendance must be 0-100%' )
                        %element-attendance_rate = if_abap_behv=>mk-on ) TO reported-gymmember.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD simulateRetention.
    DATA(lv_disc) = keys[ 1 ]-%param-discount_percent.
    READ ENTITIES OF ZI_GymMember_Adv IN LOCAL MODE
      ENTITY GymMember ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_data).
    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs_m>).
      DATA(lv_score) = 100 - <fs_m>-attendance_rate - ( lv_disc * 2 ).
      lv_score = nmax( val1 = 0 val2 = nmin( val1 = 100 val2 = lv_score ) ).
      DATA(lv_crit) = COND #( WHEN lv_score > 60 THEN 1 WHEN lv_score > 30 THEN 2 ELSE 3 ).
      READ TABLE lcl_buffer=>mt_buffer WITH KEY member_id = <fs_m>-member_id ASSIGNING FIELD-SYMBOL(<fs_b>).
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM zgym_members WHERE member_id = @<fs_m>-member_id INTO @DATA(ls_db_sim).
        INSERT ls_db_sim INTO TABLE lcl_buffer=>mt_buffer ASSIGNING <fs_b>.
      ENDIF.
      <fs_b>-retention_score = lv_score. <fs_b>-criticality = lv_crit.
      <fs_m>-PredictionScore = lv_score. <fs_m>-StatusCriticality = lv_crit.
    ENDLOOP.
    result = VALUE #( FOR r IN lt_data ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_saver DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save REDEFINITION.
ENDCLASS.

CLASS lcl_saver IMPLEMENTATION.
  METHOD save.
    IF lcl_buffer=>mt_buffer IS NOT INITIAL.
      MODIFY zgym_members FROM TABLE @lcl_buffer=>mt_buffer.
    ENDIF.
    IF lcl_buffer=>mt_delete_buffer IS NOT INITIAL.
      DATA: lt_del_tmp TYPE STANDARD TABLE OF zgym_members WITH EMPTY KEY.
      lt_del_tmp = VALUE #( FOR id IN lcl_buffer=>mt_delete_buffer ( member_id = id ) ).
      DELETE zgym_members FROM TABLE @lt_del_tmp.
    ENDIF.
    CLEAR: lcl_buffer=>mt_buffer, lcl_buffer=>mt_delete_buffer.
  ENDMETHOD.
ENDCLASS.
