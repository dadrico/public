## **TEMPORAL LAST**

TEMPORAL_LAST is used to deduplicate records. We use TEMPORAL_LAST to choose the record with a biggest value, latest date, greatest importance out of all records of the same group within a given period.

**TEMPORAL LAST aggregation example**

Let’s say we have 3 payments on an invoice and we want to choose the latest payment based on payment date (an attribute of the payment). The input looks like this:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_last1.png)

•	Row 1 is a payment inserted on Monday that never changed

•	Row 2 is the second payment which date was corrected on Wednesday (first it was registered as being made in December, but later it was found to be actually made in November)

•	Row 3 is the corrected record of the second payment

•	Row 4 is a third payment that was inserted on Thursday, but it was deemed an error (it has a clearly incorrect date) and therefore removed on Saturday

When filling the options we choose the **invoice_id** to be the group-by variable and the **date** to be the last-by variable. We map all the columns.

The output is this:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_last2.png)

Please note that even though payment_id is still present in the output, the timeline key is now 
the **invoice_id**.

Explanation:

•	Row 1 – we are choosing the record with the latest **date** among the 2 records valid in this period – these are the yellow and the green one. The **date** in green record is 2023-12-30, which is greater than 2023-12-01, therefore for this period we choose the green record.

•	Row 2 – the **date** in the green record has changed. Now the **date** of the yellow record is greater, so for this period we choose the yellow record.

•	Row 3 – within this period there are 3 valid records. Among those the greatest **date** value is in the red record and this one is chosen.

•	Row 4 – the red record is not valid anymore, so we choose the yellow record again

The job contains an example of temporal last transformation:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_last3.png)

Let's say that we want to choose the latest registered record within every validity period.

**Mappings**

The mappings are usually 1:1 – we still take all the values of the input records; the changes happen within the timelines (valid-from and valid-to columns).

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_last4.png)

**Options**

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_last5.png)

•	Group by columns – the columns that define the aggregation groups

•	Last by columns – these columns define the order in which the valid rows are sorted before the last one of them is chosen. Here we want to take the latest registered record, therefore we use valid_from. If there were more than one record with the same valid_from, then from among these, we choose the one with the latest valid_to.

•	Valid-from column – a datetime column

•	Valid-to column – a datetime column