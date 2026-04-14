DECLARE
    v_emp_id     NUMBER := 'ABC';        -- TYPE ERROR: character assigned to NUMBER
    v_salary     NUMBER;
    v_bonus      NUMBER
    v_total      NUMBER;                  -- SYNTAX ERROR: missing semicolon above

BEGIN
    -- Invalid table name or column (semantic error)
    SELECT salary
    INTO v_salary
    FROM employee_tablee                  -- TABLE DOES NOT EXIST
    WHERE emp_id = v_emp_id;

    -- Divide by zero runtime error
    v_bonus := v_salary / 0;

    -- Using undeclared variable
    v_total := v_salary + v_allowance;    -- v_allowance NOT DECLARED

    -- Incorrect IF condition syntax
    IF v_salary > 50000                   -- MISSING THEN
        DBMS_OUTPUT.PUT_LINE('High salary');
    END IF;

    -- Incorrect function name
    DBMS_OUTPT.PUT_LINE('Total: ' || v_total);  -- MISSPELLED DBMS_OUTPUT

EXCEPTION
    -- Invalid exception name
    WHEN ZERO_DIVIDED THEN                -- SHOULD BE ZERO_DIVIDE
        DBMS_OUTPUT.PUT_LINE('Math error occurred');

    -- Missing exception handler body
    WHEN NO_DATA_FOUND;

END;
/