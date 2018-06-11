/**
* @desc: This class invokes from Order object trigger and 
         Create the Asset based on the OrderItem which are of Type = 'Vehicle'.
* @author: Abhinav
* @version: 1.0.
* 
*/
public class AssetCreation {
    
    
    public static void checkPDI(List<Order> lorder){
        
        Set<Id> neworderids =  new Set<Id>();
        Map<String,String> countryname = new Map<String,String>();
        //Get the Country values from CustomMetatype using Util class.
     	countryname = Countrycodeutils.countrymapping();
        for(Order neworder:lorder){
        	String checkcountryname;
        	if(neworder.Country__c!=null) checkcountryname = neworder.Country__c;
            //if(neworder.Country__c!=null && (countryname.get('India') == checkcountryname || countryname.get('Japan') == checkcountryname) && neworder.Submit_Order__c == true)neworderids.add(neworder.id);
            if(checkcountryname!=null && (countryname.get(neworder.Country__c) == checkcountryname)) neworderids.add(neworder.id);
            System.debug('SOrder##'+neworder.Status);
            System.debug('SOrder##'+neworder.Submit_Order__c);
        }
        if(neworderids.size()>0){
        	List<Order> newlorder = [Select Id,Status,Submit_Order__c,(Select Id,Inventory__r.PDI_Done__c from OrderItems where Product2_Type__c=:System.Label.QLI_Vehicle) from Order where ID IN:neworderids];
	        for(Order corder:newlorder){
	            System.debug('SOrder##'+corder.Submit_Order__c);
	            System.debug('SOrder##'+corder.Status);
	            
	            for(OrderItem orditem:corder.OrderItems){
	                if(orditem.Inventory__r.PDI_Done__c!=System.Label.FCA_PDI_DONE_True ) {
	                    for(Order eorder:lorder){
	                    	if(eorder.Submit_Order__c == Boolean.ValueOf(System.Label.FCA_True_Check))trigger.new[0].addError(System.Label.FCA_PDI_Done_Exception);
	                    }
	                }
	            }
	        }
      	}
 	}
  
    /**
      *  This method invoke at the time of Order Status changed to 'Delivered' 
      *  This method will get Order as input and will fetch the Order items for creation of Asset
      */
    public static void createAsset(List<Order> order)
    {
        //keep savepoint to ensure complete data entered
        Savepoint sp = Database.setSavepoint();
       
        List<Asset> assetlist = new List<Asset>();
        List<Asset_Owner__c>assetownerlist = new List<Asset_Owner__c>();    
        Map<Id,Order> maporderrecs = new Map<Id,Order>();
        Set<Id> contactids = new Set<Id>(); 
        Map<String,String> countryname = new Map<String,String>(); 
        String checkcountryname;
       
        try
        {
           //Get the Country values from CustomMetatype using Util class.
            countryname = Countrycodeutils.countrymapping();
            for(Order orderval:order){
               if(orderval.Status == System.Label.FCA_Order_Delivered_Status) maporderrecs.put(orderval.Id,orderval);
          	}
    		if(maporderrecs.size()>0){                        
            List<OrderItem> Oli = [select Id, OrderId,OrderItemNumber,Product2Id,Inventory__c,Inventory_VIN__c,Engine__c,Inventory__r.PDI_Done__c from OrderItem where OrderId IN: maporderrecs.keyset() AND Inventory_VIN__c != null AND Product2_Type__c =:System.Label.FCA_Vehicle_Type];
            if(Oli.size()>0)
            {
               
                for(OrderItem orditem:Oli){
                    //create Asset instance and assign values to the Asset fields
                    //These values can be changed based on the Region /country
                    Order ordervalues = maporderrecs.get(orditem.OrderId);
                    System.debug('Test###'+ordervalues.Status);
                    String orderrecordtype = ordervalues.Country__c;
                    Id assetrectype = Schema.SObjectType.Asset.getRecordTypeInfosByName().get(orderrecordtype).getRecordTypeId();
                  
                    //Check the Country value from CustomMetadatatype 
                    if(ordervalues.Country__c!=null) checkcountryname = ordervalues.Country__c;
                    //Assign the logics depends upon Countryspecific from CustomMetadata types.
                    //if(checkcountryname!=null && (countryname.get('India') == checkcountryname || countryname.get('Japan') == checkcountryname)){
                    if(checkcountryname!=null && (countryname.get(ordervalues.Country__c) == checkcountryname)){
                        Asset asset = New Asset();
                        asset.AccountId = ordervalues.AccountId;
                        asset.CurrencyIsoCode = ordervalues.CurrencyIsoCode;
                        asset.Country__c = ordervalues.Country__c;
                        asset.AssetProvidedById = ordervalues.AccountId;
                        asset.AssetServicedById = ordervalues.AccountId;
                        /*Contact associated with the Asset -> this can be change to Shipped COntactId based on the
                        Business Requirement in Region/ Country*/
                        asset.ContactId = ordervalues.BillToContactId;
                        asset.InstallDate = System.today();
                        asset.PurchaseDate = System.today();
                        asset.Price = ordervalues.TotalAmount;
                        asset.OrderId__c = ordervalues.Id;
                        if(ordervalues.Registered_Owner_of_Car__c != NULL) asset.Registered_Owner_of_Car__c = ordervalues.Registered_Owner_of_Car__c;
                       if(assetrectype!=null) asset.RecordTypeId = assetrectype;
                        System.debug(Oli);
                        //asset.Name can be changed based on the country/region
                        //asset.Name = ordervalues.OrderNumber;
                        asset.Name = orditem.Inventory_VIN__c;//For India
                        asset.Description = 'Asset from Order-> ' + ordervalues.OrderNumber + ' Order Item -> ' + orditem.OrderItemNumber; 
                        asset.Product2Id = orditem.Product2Id;
                        asset.SerialNumber = orditem.Inventory_VIN__c;
                        asset.Engine__c = orditem.Engine__c;
                        System.debug(asset);
                        if(ordervalues.Status == System.Label.Order_Delivered && orditem.Inventory__r.PDI_Done__c == System.Label.FCA_PDI_DONE_True){
                             assetlist.add(asset);
                        }    
                }
                //checking if Asset has any record to be inserted
                if(assetlist.size()>0){
                    //insert Asset Record
                   RecursiveTriggerHandler.callQuotelineitem = false;
                   insert assetlist; 
                } 
                //INsert Asset Owner Record for tracking the Vehicle Users
                if(assetlist.size()>0){
                    
                    for(Asset aid:assetlist){
                        ordervalues = maporderrecs.get(aid.OrderId__c);
                        contactids.add(ordervalues.BillToContactId);
                        
                        String rectypeasset = ordervalues.Country__c;
                        Id assetownerrectype = Schema.SObjectType.Asset_Owner__c.getRecordTypeInfosByName().get(rectypeasset).getRecordTypeId();
                        InventoryService2Asset.AssocInv2Asset(aid.Id);//Inventory Service to be added for the Asset Also.
                        Asset_Owner__c assetowner = New Asset_Owner__c();
                        assetowner.Contact__c = ordervalues.BillToContactId;
                        assetowner.Asset__c = aid.Id;
                        assetowner.Name = aid.Name;
                        assetowner.Registration_StartDate__c = System.today();
                        if(assetownerrectype!=null) assetowner.RecordtypeId = assetownerrectype;
                        assetownerlist.add(assetowner);
                        //checking any assetowner to be inserted or not
                        if(assetownerlist.size()>0)
                             insert assetownerlist; //insert Asset Owner Record
                    }
                }
                if(contactids.size()>0 && assetownerlist.size()>0){
                    List<Contact> listofcontacts = new List<Contact>();
                    List<Contact> contactlist = [Select Id,Vehicle_Owner__c from Contact where ID IN:contactids];
                    for(Contact conrecs:contactlist){
                        conrecs.Vehicle_Owner__c = true;
                        listofcontacts.add(conrecs);
                    }
                    
                    if(listofcontacts.size()>0) update listofcontacts;
                }
              }
            }
    	}
            else
                System.debug('Order Does not have Inventory');
        }
       catch(Exception e) 
        {
            //Rollback to avoid incomplete dataentry in the Database
            Database.rollback(sp);
            System.debug('An exception occurred: ' + e.getMessage());
        }
        //return Asset Id's
        //return assetId;
    }
    
}