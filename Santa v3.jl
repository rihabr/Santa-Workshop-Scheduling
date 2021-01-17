using JuMP, Gurobi, DataFrames, CSV, Plots

using Pkg
Pkg.add(Pkg.PackageSpec(name="JuMP", version="0.18.6"))


preferences = CSV.read("family_data.csv")
fam_size = preferences[:,12]
sort(fam_size,rev=true);

#### Create Cost Vector for Preference Cost (Penalty Term #1)
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

#### Calculate Preference Cost (Penalty Term #1)
function calcPrefCost(x)
    
    sum(c[i,j]*x[i,j] for i =1:5000,j=1:100)
    
    return prefCost
end

#### Calculate Accounting Cost (Penalty Term #2)
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

#### Optimization Formulation
    model = Model(solver=GurobiSolver(TimeLimit=60*10))

    #Decision Variables
        ##whether family i gets assigned to day j
    @variable(model, x[i=1:5000, j=1:100],Bin)
        ## whether Day d has i people and Day d+1 has j people 
    @variable(model, N[d=1:99,i=125:300, j=125:300],Bin)

    #CONSTRAINTS

#     # (1) each family can only be assigned one day
    @constraint(model, [i=1:5000] ,sum(x[i,j] for j=1:100)==1) 

#     # (2) for each day d, we can only one value for i and j
    @constraint(model, [d=1:99], sum(N[d,i,j] for i=125:300, j=125:300)==1)
#     @constraint(model, sum(N[100,i,i] for i=125:300) ==1)

#     # (3) for each day d, the number of people on a day from Ndij is consistent with the family assignments from xij
    @constraint(model, [d=1:99], sum(N[d,i,j]*i for i=125:300, j=125:300)== sum(x[i,d]*fam_size[i] for i=1:5000))
    @constraint(model, [d=1:99], sum(N[d,i,j]*j for i=125:300, j=125:300)== sum(x[i,d+1]*fam_size[i] for i=1:5000))

    # objective function
    @objective(model, Min, sum(c[i,j]*x[i,j] for i =1:5000,j=1:100)+ 
    sum( ( ((i - 125)/400) * i^(0.5 + (abs(i-j)/50 )) )*N[d,i,j] for d=1:99,i=125:300,j=125:300)  
    + sum( ( ((j - 125)/400) * j^(0.5 + (abs(j-j)/50 )) )*N[99,i,j] for i=125:300,j=125:300) )

  # Run model
    solve(model)

    #Store decision variable solutions
    x = getvalue(x);
    totalCost = getobjectivevalue(model)

### Function for  santa's schedule
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


submission_final = convert(DataFrame, sched)
CSV.write("submission_VR_5.csv", submission_final, header=["family_id","assigned_day"])

