using JuMP, Gurobi, DataFrames, CSV, Plots

preferences = CSV.read("family_data.csv")
fam_size = preferences[:,12]
fam_size[2]

min(6,8)

#need to create vector such the 52nd entry has cost 0, 38th entry has cost 1 etc....
#then, for the second family 100 + 26th entry has cost 0, 4th entry has cost 1 etc....
c = zeros(5000,100)

for i=1:5000
    
    n = fam_size[i]

    for j=1:100
        
        c[i,j]=500 + 36*n + 398*n
        
    end
    
end

for i=1:5000
    
    n = fam_size[i]
    
    for j=2:11
        
        day_preferred = preferences[i,j] 
        
        if j-2==0 
            c[i,day_preferred] = 0
        elseif j-2==1
            c[i,day_preferred] = 50  
        elseif j-2==2
            c[i,day_preferred] = 50  + 9*n
        elseif j-2==3
            c[i,day_preferred] = 100  + 9*n
        elseif j-2==4
            c[i,day_preferred] = 200  + 9*n
        elseif j-2==5
            c[i,day_preferred] = 200  + 18*n
        elseif j-2==6
            c[i,day_preferred] = 300  + 18*n
        elseif j-2==7
            c[i,day_preferred] = 300  + 36*n
        elseif j-2==8
            c[i,day_preferred] = 400  + 36*n
        else
            c[i,day_preferred] = 500  + 36*n + 199*n
        end
        
    end
end


function calcPrefCost(x)
    
    sum(c[i,j]*x[i,j] for i =1:5000,j=1:100)
    
    return prefCost
end

function calcAccountingCost(schedule)
    
    day = schedule[:,2]
    fam_size = preferences[:,12]
    day_fam_size = hcat(day, fam_size)
    df_day_fam_size = convert(DataFrame, day_fam_size)
    
    grp_day = groupby(df_day_fam_size, :x1)
    ppl_by_day = combine(grp_day, :x2 => sum)
    N = sort(ppl_by_day, rev=true) #PPL BY DAY, sorted
    
    penalty = 0
    for i = 2:100
        penalty += ( (N[i,2] - 125) / 400 ) * N[i,2]^(0.5 + ( abs(N[i,2]-N[i-1,2])/50 ) )
    end 
    
    penalty += ( (N[1,2] - 125) / 400 ) * N[1,2]^(0.5 + ( abs(N[1,2]-N[1,2])/50 ) )

    return penalty
end

    model = Model(solver=GurobiSolver(TimeLimit=60*4))
    @variable(model, x)
    @variable(model, y)

    @constraint(model, 5x+3y<=3) 

    @objective(model, Min, x+y)

solve(model)


    model = Model(solver=GurobiSolver(TimeLimit=60*4))

    #Decision Variables
        ##whether family i gets assigned to day j
    @variable(model, x[i=1:5000, j=1:100],Bin)
        ## whether Day d has i people and Day d+1 has j people 
    @variable(model, N[d=1:100,i=125:300],Bin)

    #CONSTRAINTS

#     # (1) each family can only be assigned one day
    @constraint(model, [i=1:5000] ,sum(x[i,j] for j=1:100)==1) 

#     # (2) for each day d, we can only one value for i 
    @constraint(model, [d=1:100], sum(N[d,i] for i=125:300)==1)

#     # (3) for each day d, the number of people on a day from Ndi is consistent with the family assignments from xij
    @constraint(model, [d=1:100], sum(N[d,i]*i for i=125:300)== sum(x[i,d]*fam_size[i] for i=1:5000))

    # objective function
    @objective(model, Min, sum(c[i,j]*x[i,j] for i =1:5000,j=1:100)+ 
    sum( min((((i - 125)/400) * i^(0.5 + (abs(i-j)/50 ))),69000)*N[d,i]*N[d+1,j] for d=1:99,i=125:300,j=125:300)  
    + sum( ( ((j - 125)/400) * j^0.5)*N[100,j] for j=125:300) )

  # Run model
    solve(model)

    #Store decision variable solutions
    x = getvalue(x);
    totalCost = getobjectivevalue(model)


function createSchedule(x)
    
    submission = zeros(5000,1)

    for i=1:5000
        for j=1:100
           if x[i,j] !=0 
                submission[i]= j
            end
        end
    end

    famID = preferences[:,1]
    submission = hcat(famID, submission)
    
    return submission
    
end

## Evaluate 

prefCost = calcPrefCost(x)
sched = createSchedule(x)
accCost = calcAccountingCost(sched)
totalCost = prefCost+accCost

x

submission_final = convert(DataFrame, sched)
CSV.write("submission_VR_5.csv", submission_final, header=["family_id","assigned_day"])

sched =  CSV.read("best_submission.csv");

x = convert(DataFrame, x)
CSV.write("test.csv", x)

x = DataFrame(A = 1:4, B = ["M", "F", "F", "M"])
CSV.write("test.csv", x)


