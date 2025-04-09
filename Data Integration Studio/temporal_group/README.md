## **TEMPORAL GROUP**

TEMPORAL GROUP is a transformation that aggregates (select … from … group by) values of records grouped by a common key. It takes the validity periods into consideration. The result is a timeline which represents all changes in any of the records within the group.

**TEMPORAL GROUP aggregation example**

Let’s say we want to aggregate the payments on invoices.
In our input to the TEMPORAL_GROUP we have 3 different payments for the same invoice (201). 

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_group1.png)

•	Row 1 is a payment inserted on Monday that never changed

•	Row 2 is the second payment also added on Monday, which value was later corrected on Wednesday

•	Row 3 is the corrected record of the second payment

•	Row 4 is the third payment that was inserted on Thursday

We are aggregating on invoices, so the group-by column is here the **invoice_id** and this becomes our timeline key of the output table. The payment_id won’t appear in the output dataset. 
We map the value to the column **sum_value**, writing **sum(value)** in the expressions.

And this is the output:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_group2.png)

Explanation:

•	Row 1 is the sum of $${\color{#d6b040}€20}$$ + $${\color{#3a7a13}€30}$$ = €50  – the only 2 records valid in this period

•	Row 2 is the sum of $${\color{#d6b040}€20}$$ + $${\color{#3a7a13}€40}$$ = €60  – the only 2 records valid in this period

•	Row 3 is the sum of $${\color{#d6b040}€20}$$ + $${\color{#3a7a13}€40}$$ + $${\color{#3572a8}€50}$$ = €110 – the 3 records valid after 2024-01-04

The job contains an example of temporal group transformation:

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_group3.png)

It aggregates all the measurements of a given measurement definition by day.

**Mappings**

In case of the temporal group transformation, it is crucial to correctly map the data. Just as it is with a regular SQL group-by statement, the output columns can be either the key columns defining the aggregation group or the aggregated columns themselves. Here we also add the valid-from and valid-to dates defining the validity periods. You can use any PROC SQL aggregation function available in SAS.

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_group4.png)

**Options**

![image](https://raw.githubusercontent.com/dadrico/public/main/Data%20Integration%20Studio/.images/temporal_group5.png)

•	Group by columns – the columns that define the aggregation groups

•	Valid-from column – a datetime column 

•	Valid-to column – a datetime column