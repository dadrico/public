In this section you can find a colleciton of SAS Data Integration Studio transformations that you can use in your projects.

In order to use a trasformation you need to create it in your metadata. To do that:

1. Create a new transformation:
   
   ![image](https://github.com/user-attachments/assets/6e0a9771-280e-4c0f-8613-450bf7a55c48)

2. Paste the SAS code from a .sas file to the wizard's SAS Code window:

   ![image](https://github.com/user-attachments/assets/9e1c6c8d-9dfe-45dc-8fb7-1852f2a85053)

3. Import options from a .xml file in the wizard's Options window:

   ![image](https://github.com/user-attachments/assets/5ad8bddf-6779-4c1f-92fe-f7239586a013)

4. Tick the right boxes in the wizard's Transform properties window. The correct options are always given in the comment section of the code in the .sas file:

   > * Inputs/Outputs settings:
   > * [v] Transformation supports inputs (min=1, max=1)
   > * [v] Transformation supports outputs (min=1, max=1)
   > * [v] Automaticallygenerate delete code for outputs
   > * [v] Generate column mapping macros
   
   ![image](https://github.com/user-attachments/assets/21406ffe-7032-4c2d-9623-11712e83717e)

5. Complete the wizard and you're ready to go. Enjoy!
