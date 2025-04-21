integer main()
begin
    integer sum = 0;
    integer i = 0;

    for (i = 0; i < 10; i = i + 1)
        sum = sum + i;

    integer a = 10, b = 5;
    integer result_simple_if, result_ifelse1;

    if (a > b) // 10 > 5 is true
    begin
        result_simple_if = 1;
    end

    if (a == 10) 
    begin
        result_ifelse1 = 100; 
    end
    else
    begin
        result_ifelse1 = 199;
    end    

    integer x = 2 + 2;
end
