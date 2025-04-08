## **HIERARCY SEARCH**

HIERARCY SEARCH is a transformation that finds values in hierarchical relations.
The transformation has 4 functions defined for use in mapping expressions:

**getFromRoot**(column) - find the root record of the current leaf record and get a value of a [column] column value of that root record
**getFromParent**(column) - find the parent record of the current leaf record and get a value of a [column] column value of that parent record
**getFromAncestorLevel**(column,level) - find the ancestor record [level] levels above the current leaf record and get a [column] column value of that ancestor record
**getRootPath**() - returns the path of keys of all ancestors up to the root as a string
> NOTE: getFromAncestorLevel(some_column, 1) is the same as getFromParent(some_column)

**HIERARCHY SEARCH EXAMPLES**

Let's take a following table containing parent - child relations:

![image](.images/hierarchy_search1.png)

The following expression definitions:

![image](.images/hierarchy_search2.png)

...will result in the following output table:

![image](.images/hierarchy_search3.png)



**Mappings**

These new columns are defined using the appropriate functions in the expression section of the column mapping
![image](.images/hierarchy_search4.png)


**Options**

It is also required to provide the columns containing the child and parent keys
![image](.images/hierarchy_search5.png)