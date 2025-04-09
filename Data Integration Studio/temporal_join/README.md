## **TEMPORAL JOIN**

When joining two tables in which the data can change over time, the temporal join transformation should be used. It combines the timelines from both tables resulting in one common timeline where the changes of the both joined tables are represented in the output.

**TEMPORAL JOIN example**

Let’s take a table with invoices as our LEFT input table. It contains one invoice that changes its status over time:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_join1.png)

As the RIGHT input table let’s take the payments:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_join2.png)

•	Row 1 is the first payment that was added on Wednesday and which value was later corrected on Thursday

•	Row 2 is the corrected record of the first payment

•	Row 3 is the second payment that was inserted on Saturday

The <ins>key</ins> of the LEFT table is **invoice_id**.

The <ins>join condition</ins> is: **L.invoice_id = R.invoice_id**.

The output is as follows:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_join3.png)

Explanation:

•	Row 1 – in the first period the status of the invoice is DRAFT and there is no payment yet, therefore the payment columns are empty

•	Row 2 – the change of the status is represented in the output. Still there are no payments, so the payment columns stay empty.

•	Row 3 – the status remains SENT, but there is now a payment nr 112 of €30

•	Row 4 – the status is still SENT, but the value of the payment changes to €40 because of the correction; until now we still have one record per period

•	Row 5 – the value of the payment 112 remains €40, but now the status changes to PAID, so the previous record is closed and the new record is added

•	Row 6 – within the same period another payment (113) is registered. The status of the invoice in this period is PAID. 

> NOTE: There are now 2 valid records within the same period.

The key of the output is therefore composite and consists of 2 columns: **invoice_id + payment_id**.

This job contains an example of a temporal join:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_join4.png)

**Mappings**

In the left pane there are all the columns from both source tables. We map all the columns that we want to output. Note that there are two sets of valid_from/_to columns in the input pane. In the output the transformation will make one timeline based on the two input timelines. Therefore, only one set of valid_from/_to columns is required in the output. For consistency it is advised to map these columns from the left (first) input table, but the transformation will work either way with exactly the same result.

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_join5.png)

**Options**

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_join6.png)

•	Key columns – these are the columns that – together with valid_to – define the primary key of the left (first) input table. In this transformation it is possible that the output key is different from the key of the left input table. As it is with regular joins, if there are many records in the right (second) input table that meet the join conditions for a given key, there will be multiple records for this key in the output.

•	Join type – LEFT join or INNER join. For right join switch the tables in the input. Outer join is not allowed because it can easily lead to issues with the key and as a result duplicate records.

•	Join condition – here the join condition can be defined using SAS PROC SQL syntax. Use L for the LEFT (first) input table and R for the RIGHT (second) input table as an alias for the columns used in the expression. The join condition is meant to be used just as if we’re joining the current status. The transformation will take care of the timeline automatically, so there is no need to include any of the timeline columns (valid_from/_to) in the join condition.

•	Valid-from column – a datetime column 

•	Valid-to column – a datetime column

•	Segment size – this transformation is quite memory-heavy, so when joining big input tables, the join operation is divided into pieces and then the results are appended to create the output table. By default, the size of the segment is determined by the &defaultTLJoinSegmentSize parameter. We estimate that, depending on the table width, the optimum segment size is somewhere between 500k records and 5M records. Currently it is set to 1M records. We know no easy way to determine the optimum, so if there is a performance issue, feel free to adjust the value of this option and check if it helps.