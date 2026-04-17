-----------------------------------------------------------------------------
--
--  Logical unit: CHubRecharge
--  Component:    GENLED
--
--  IFS Developer Studio Template Version 3.0
--
--  Date    Sign    History
--  ------  ------  ---------------------------------------------------------
-- 260128  ArcSubanK Redmine#6291(CR):hub refac - compte a refacturer = non
--  250812 ArcAmarek CRIME #5766 -M833 - Printing and Merging Hub Instant Invoices
--  250716  ArcSubanK Redmine#6007: Added new logic to fetch the invoice date for sales invoice and purchase invoice for the existing records
--  250310 ArcSubanK M494:Redmine#CR:5314,5364,5432 and RW:5343
--  230803  ArcSubanK M494/M577: logic created to handle RechargeId and LogDate coulmns
-----------------------------------------------------------------------------

layer Cust;

-------------------- PUBLIC DECLARATIONS ------------------------------------


-------------------- PRIVATE DECLARATIONS -----------------------------------


-------------------- LU SPECIFIC IMPLEMENTATION METHODS ---------------------
/* Procedure Check_Insert___ is a standard IFS procedure, overrided to add additional busniess logic to validate the hub recharge columns before inserting the records*/
@Override
PROCEDURE Check_Insert___ (
   newrec_ IN OUT C_HUB_RECHARGE_TAB%ROWTYPE,
   indrec_ IN OUT Indicator_Rec,
   attr_   IN OUT VARCHAR2 )
IS
   -- (+)250716 ArcSubanK Redmine#6007(Start)
   CURSOR check_prd_status(recharge_type_ VARCHAR2,company_ VARCHAR2,acc_year_ NUMBER,acc_period_ NUMBER)
IS 
      SELECT 
         period_status_db
      FROM USER_GROUP_PERIOD u
      WHERE company = company_ 
      AND accounting_year= acc_year_
      AND accounting_period = acc_period_
      AND EXISTS(SELECT 1
                  FROM C_RECHARGE_TYPE_USER_GROUP c
                  WHERE c.company=u.company
                  AND c.user_group=u.user_group
                  AND c.recharge_type_id=recharge_type_);
                  
   CURSOR get_acc_period(recharge_type_ VARCHAR2,company_ VARCHAR2,acc_year_ NUMBER,acc_period_ NUMBER,period_status_ VARCHAR2)
IS 
      SELECT 
         accounting_period
      FROM USER_GROUP_PERIOD u
      WHERE company = company_ 
      AND accounting_year= acc_year_
      AND accounting_period BETWEEN acc_period_  AND extract(MONTH FROM sysdate)
      AND period_status_db =period_status_
      AND EXISTS(
         SELECT 1
         FROM C_RECHARGE_TYPE_USER_GROUP c
         WHERE c.company=u.company
         AND c.user_group=u.user_group
         AND c.recharge_type_id=recharge_type_)
         ORDER BY company,accounting_year,accounting_period; 
   months_   NUMBER := NULL;      
   status_   USER_GROUP_PERIOD.period_status_db%TYPE := NULL;
   acc_yr_ ACC_PERIOD_LEDGER.accounting_year%TYPE:=NULL;
   acc_prd_ ACC_PERIOD_LEDGER.accounting_year%TYPE:=NULL;
   -- (+)250716 ArcSubanK Redmine#6007(Finish) 
   
   
   --(+)250310 ArcSubanK M494:Redmine#5314,5364 and 5343(Start)
   CURSOR get_hub_media(customer_id_ VARCHAR2) 
IS 
      SELECT 
      1
      FROM CUSTOMER_INFO_MSG_SETUP 
      WHERE customer_id=customer_id_
      AND media_code= 'HUB';
   exist_ NUMBER := 0;
   period_status_ VARCHAR2(1) := 'O';
   current_status_ VARCHAR2(4000) := 'Instant Invoice To Be Created';
   --(+)250310 ArcSubanK M494:Redmine#5314,5364 and 5343(finish)
BEGIN
   --Add pre-processing code here
   IF newrec_.quantity_source IS NULL 
   THEN 
      newrec_.quantity_source:=1;
   END IF;
   newrec_.recharge_id:=Get_Recharge_Id;
   --Error_SYS.Record_General(lu_name_, newrec_.recharge_id);
   newrec_.current_status:=current_status_;
   -- (+)250716 ArcSubanK Redmine#6007(Start) 
   status_ := NULL;
   acc_yr_ := NULL;
   acc_prd_ := NULL;
   acc_yr_ := extract(YEAR FROM newrec_.voucher_acc_date_source);
   acc_prd_ := extract(MONTH FROM newrec_.voucher_acc_date_source);
   months_ := NULL; 
   
   OPEN  check_prd_status(newrec_.recharge_type ,newrec_.company_source,acc_yr_,acc_prd_);
   FETCH check_prd_status INTO status_;
   CLOSE check_prd_status;
   
   IF status_ !=period_status_
   THEN
      OPEN  get_acc_period(newrec_.recharge_type ,newrec_.company_source,acc_yr_,acc_prd_,period_status_);
      FETCH get_acc_period INTO months_;
      CLOSE get_acc_period;
      
      months_ := abs(months_ - acc_prd_);     
      newrec_.date_sales_inst_inv := last_day(add_months(newrec_.voucher_acc_date_source,months_)); 
   ELSE 
      newrec_.date_sales_inst_inv := newrec_.voucher_acc_date_source;
   END IF;
   -- (+)250716 ArcSubanK Redmine#6007(Finish) 
   -- (+)260128  ArcSubanK Redmine#6291(CR)(Start)
   IF (newrec_.account_source LIKE '613%' OR newrec_.account_source LIKE '614%') AND upper(newrec_.fiancial_project_source) = 'REFAC'
   THEN
      newrec_.to_recharge :='FALSE';
   END IF;
   -- (+)260128  ArcSubanK Redmine#6291(CR)(Finish)   
   super(newrec_, indrec_, attr_);
   --(+)250310 ArcSubanK M494:Redmine#5314,5364 and 5343(Start)
      exist_ := 0;
      OPEN  get_hub_media(newrec_.interco_re_sales_inst_inv);
      FETCH get_hub_media INTO exist_;
      CLOSE get_hub_media;
      
      IF nvl(exist_,0) = 0
      THEN
         newrec_.inter_comp_client:='TRUE';
      ELSE 
         newrec_.inter_comp_client:='FALSE';
      END IF;
      --(+)250310 ArcSubanK M494:Redmine#5314,5364 and 5343(Finish)
   --Add post-processing code here
   EXCEPTION
   WHEN OTHERS
   THEN
	NULL;
END Check_Insert___;
/* Procedure Check_Common___ is a standard IFS procedure, overrided to add he default values for the column log_date, also this procedure will be validate when new records are created or old records are updated */
@Override
PROCEDURE Check_Common___ (
   oldrec_ IN     C_HUB_RECHARGE_TAB%ROWTYPE,
   newrec_ IN OUT C_HUB_RECHARGE_TAB%ROWTYPE,
   indrec_ IN OUT Indicator_Rec,
   attr_   IN OUT VARCHAR2 )
IS
BEGIN
   --Add pre-processing code here
   newrec_.log_date:=trunc(sysdate);
   super(oldrec_, newrec_, indrec_, attr_);
   --Add post-processing code here
END Check_Common___;







-------------------- LU SPECIFIC PRIVATE METHODS ----------------------------


-------------------- LU SPECIFIC PROTECTED METHODS --------------------------


-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------


-------------------- LU CUST NEW METHODS -------------------------------------
/*Function Get_Recharge_Id is used to get the max(Recharge_id)to avoid the duplicate entry of recharge id*/
FUNCTION Get_Recharge_Id RETURN NUMBER
IS 
   id_ NUMBER;
   CURSOR getRechargeId IS
   SELECT max(Recharge_id)
   FROM C_HUB_RECHARGE_TAB;
BEGIN
   OPEN getRechargeId;
   FETCH getRechargeId INTO id_;
   CLOSE getRechargeId;
   IF id_ IS NULL 
   THEN
      id_:=1;
   ELSE    
      id_:=id_+1;
   END IF;
   RETURN id_;
END Get_Recharge_Id; 


--(+)250812 arcamarek M753-1 (start)
/* Procedure C_Merge_Hub_Invoices is used to merge multiple pdfs attached in the document management against an individual invoice into single pdf files*/
PROCEDURE C_Merge_Hub_Invoices(
   attr_ IN OUT VARCHAR2 )
IS
 
   key_ref_               VARCHAR2(4000);
   layout_name_            varchar2(2000):= 'InstantInvoiceRep.rdl';
   c_report_id_               varchar2(2000):= 'INSTANT_INVOICE_REP';
   report_attr_             varchar2(2000);

 c_attr_pdf_      VARCHAR2(2000);
 
  c_identity_                 VARCHAR2(20);
   c_invoice_address_id_       VARCHAR2(50);
   c_serie_id_                 VARCHAR2(20);
   c_invoice_no_               CUSTOMER_ORDER_INV_HEAD.invoice_no%TYPE;
   c_contract_                 CUSTOMER_ORDER_INV_HEAD.contract%TYPE;
   c_company_                  CUSTOMER_ORDER_INV_HEAD.company%TYPE;
   c_invoice_id_               CUSTOMER_ORDER_INV_HEAD.invoice_id%TYPE;
 
   c_invoice_date_           DATE;
  
   c_info_                VARCHAR2(2000);
   c_objid_               VARCHAR2(32000);
   c_objversion_          VARCHAR2(32000);
    CURSOR cur_printer_id(descrip_ IN VARCHAR2) IS
      SELECT PRINTER_ID FROM LOGICAL_PRINTER
      WHERE  DESCRIPTION = descrip_;
      
   
  -- c_stmt_                VARCHAR2(2000);
  c_user_timestamp_ VARCHAR2(200);
  cursor get_pdf(doc_no_ NUMBER) is
    select edm.file_data from doc_reference_object obj    
    inner join  edm_file_storage edm
      on obj.doc_no = edm.doc_no and obj.doc_sheet = edm.doc_sheet and obj.doc_rev = edm.doc_rev and obj.doc_class= edm.doc_class
    where obj.lu_name in ('InstantInvoice') 
     AND obj.doc_no = doc_no_  
      and obj.doc_class ='INVOICE';
      
   CURSOR get_pdf_invoice(result_key_ IN NUMBER,print_job_id_ number)IS  
   select pdf from 
   pdf_archive
   where RESULT_KEY=result_key_ 
   AND PRINT_JOB_ID=print_job_id_ 
   order by result_key desc;
      
CURSOR get_report_invoice_not_transfered IS
   SELECT result_key,print_job_id,rowid objid,to_char(rowversion,'YYYYMMDDHH24MISS') objversion
   FROM c_merge_hub_invoice_tab
   WHERE pdf IS NULL
   AND id IS NULL
   AND owner=fnd_session_api.Get_Fnd_User;
   
   CURSOR get_doc_type (doc_no_ NUMBER )IS 
   SELECT doc_type FROM edm_file WHERE doc_no = doc_no_;
   i_ NUMBER:=0;
   c_pdf_   BLOB;
   c_doc_no_  NUMBER;
   c_doc_rev_ VARCHAR2(50);
   c_doc_class_ VARCHAR2(50);
   c_doc_sheet_ NUMBER;
   c_doc_type_ VARCHAR2(50);
    l_error_msg VARCHAR2(4000):= 'Success - No error';
      
BEGIN
  key_ref_ := 'COMPANY=' ||Client_SYS.Get_Item_Value('COMPANY', attr_)|| '^INVOICE_ID=' ||Client_SYS.Get_Item_Value('INVOICE_ID', attr_)  || '^';
  --Create the print job as no_print_out
  report_attr_:= 'REPORT_ID'||chr(31)||c_report_id_||chr(30)||'LAYOUT_NAME'||chr(31)||layout_name_||chr(30);
  
  
   c_invoice_id_             := Client_SYS.Get_Item_Value('INVOICE_ID', attr_);
   c_invoice_date_           := Client_SYS.Attr_Value_To_Date(Client_SYS.Get_Item_Value('INVOICE_DATE', attr_));
   c_identity_               := Client_SYS.Get_Item_Value('IDENTITY', attr_);
   c_invoice_address_id_     := Client_SYS.Get_Item_Value('ADDRESS_ID', attr_);
   c_serie_id_               := Client_SYS.Get_Item_Value('SERIE_ID', attr_);
   c_invoice_no_             := Client_SYS.Get_Item_Value('INVOICE_NO', attr_);
   c_contract_               := Client_SYS.Get_Item_Value('CONTRACT', attr_);
   c_company_                := Client_SYS.Get_Item_Value('COMPANY', attr_);
   c_user_timestamp_         := Client_SYS.Get_Item_Value('USER_TIMESTAMP', attr_);
   c_doc_no_                := Client_SYS.Get_Item_Value('DOC_NO', attr_);
   c_doc_rev_                := Client_SYS.Get_Item_Value('DOC_REV', attr_);
   c_doc_class_                := Client_SYS.Get_Item_Value('DOC_CLASS', attr_);
   c_doc_sheet_                := Client_SYS.Get_Item_Value('DOC_SHEET', attr_);
    
    OPEN get_doc_type(c_doc_no_);
    FETCH get_doc_type INTO c_doc_type_;
    CLOSE get_doc_type;
    
  
 
        
   Batch_Transfer_Handler_Api.Copy_From_Repo_To_Db(
      l_error_msg,
      c_doc_class_,        
      c_doc_no_,       
      c_doc_sheet_,  
      c_doc_rev_,   
      c_doc_type_ );

 
    OPEN get_pdf(c_doc_no_) ;
   FETCH get_pdf INTO c_pdf_ ;
   CLOSE get_pdf;

   Client_SYS.Clear_Attr(c_attr_pdf_);
   Client_SYS.Add_To_Attr('RESULT_KEY', result_key_seq.nextval, c_attr_pdf_);
   Client_SYS.Add_To_Attr('FILE_NAME', Client_SYS.Get_Item_Value('COMPANY', attr_)
                  ||'_'||Client_SYS.Get_Item_Value('IDENTITY', attr_)
                  ||'_'||Client_SYS.Get_Item_Value('INVOICE_NO', attr_)
                  ||'_'||Client_SYS.Get_Item_Value('SERIES_ID', attr_)||'_HUB'||'.pdf', c_attr_pdf_);
   Client_SYS.Add_To_Attr('COMPANY', Client_SYS.Get_Item_Value('COMPANY', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('COMPANY_GROUP', Client_SYS.Get_Item_Value('COMPANY_GROUP', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('RECHARGE_TYPE', Client_SYS.Get_Item_Value('RECHARGE_TYPE', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('INVOICE_ID', Client_SYS.Get_Item_Value('INVOICE_ID', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('SERIES_ID', Client_SYS.Get_Item_Value('SERIES_ID', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('INVOICE_NO', Client_SYS.Get_Item_Value('INVOICE_NO', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('IDENTITY', Client_SYS.Get_Item_Value('IDENTITY', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('INVOICE_DATE', Client_SYS.Get_Item_Value('INVOICE_DATE', attr_), c_attr_pdf_);
   Client_SYS.Add_To_Attr('OWNER', fnd_session_api.Get_Fnd_User, c_attr_pdf_);
   Client_SYS.Add_To_Attr('CREATED', sysdate, c_attr_pdf_);
   Client_SYS.Add_To_Attr('PRINT_JOB_ID',print_seq.nextval, c_attr_pdf_);
   Client_SYS.Add_To_Attr('PDF_GENERATE', 0, c_attr_pdf_);
   Client_SYS.Add_To_Attr('PDF_GLOBAL', 0, c_attr_pdf_);
   Client_SYS.Add_To_Attr('USER_TIMESTAMP',  Client_SYS.Get_Item_Value('USER_TIMESTAMP', attr_), c_attr_pdf_);   

   Transaction_SYS.Set_Status_Info('c_attr_pdf_:'||c_attr_pdf_, 'INFO');
   C_Merge_Hub_Invoice_API.NEW__(c_info_, c_objid_, c_objversion_, c_attr_pdf_, 'DO');
   i_:=0;
    FOR rec_ IN get_report_invoice_not_transfered LOOP
   Client_SYS.Clear_Attr(c_attr_pdf_);
   Client_SYS.Add_To_Attr('ID', 1, c_attr_pdf_);
   Client_SYS.Add_To_Attr('LAYOUT_NAME', 'InstantInvoiceRep.rdl', c_attr_pdf_);
   C_Merge_Hub_Invoice_API.Modify__(c_info_, rec_.objid, rec_.objversion, c_attr_pdf_, 'DO');
   C_Merge_Hub_Invoice_API.Write_Pdf__(rec_.objversion, rec_.objid, c_pdf_);  
   i_:=i_+1;   
    END LOOP; 
    @ApproveDynamicStatement(2025-09-19,ARCAMAREK)
    EXECUTE IMMEDIATE 'Delete from  edm_file_storage_tab where doc_no= :c_doc_no_' USING c_doc_no_;

-- Trace_SYS.Message(msg_, channel_id_)
END C_Merge_Hub_Invoices;
--(+)250812 arcamarek M753-1 (Finish)