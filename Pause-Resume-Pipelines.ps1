###############################################--PARAMETER DEFINING--#################################################### 
param([string]$rg="CSSDev",[string]$sub="IMAP-EDW-Dev-ITG",[string]$df="css205784dev-df",[string]$Pause ="true",[bool]$nq=$false)


################################################--RE-USABLE SCRIPT VARIABLES--####################################################
$DisplayDetails={
                Write-Host `n'ResourceGroupName:' $ResourceGroupName
                Write-Host 'Subscription:'$Subscription
                Write-Host 'DataFactoryName:'$DataFactoryName
                Write-Host 'Pause Pipelines:' $Pause 

}

$LoginAzure={
                Try {
                  $temp=Get-AzureRmContext
                  if(!$temp.Environment)
                  {
                   Login-AzureRmAccount
                  }
                } Catch {
                  if ($_ -like "*Run Login-AzureRmAccount to login*") {
                    Login-AzureRmAccount
                  }
                }
}


$ChangeDetails={
                $IsChangeDetails='n';
                $IsChangeDetails=Read-Host -Prompt 'Do you want to change the details(y/anyotherkey)'
                if($IsChangeDetails-eq 'y')
                {
                $prompt=Read-Host -Prompt "Enter ResourceGroupName(Press enter to accept the default) [$($ResourceGroupName)]"
                $ResourceGroupName = ($ResourceGroupName,$prompt)[[bool]$prompt]
                $prompt=Read-Host -Prompt "Enter Subscription(Press enter to accept the default) [$($Subscription)]"
                $Subscription = ($Subscription,$prompt)[[bool]$prompt]
                $prompt=Read-Host -Prompt "Enter DataFactoryName(Press enter to accept the default) [$($DataFactoryName)]"
                $DataFactoryName = ($DataFactoryName,$prompt)[[bool]$prompt]
                $prompt=Read-Host -Prompt "What action you want to perform Pause(true) Resume(false)(Press enter to accept the default) [$($Pause)]"
                $Pause = ($Pause,$prompt)[[bool]$prompt]

                &$DisplayDetails
}
}

#################################################################################################################################



&$LoginAzure

#region Parameter assignment
$ResourceGroupName=$rg
$Subscription=$sub
$DataFactoryName=$df
$NoQuestion=$nq
$PipelineName=$pname
#endregion


&$DisplayDetails

if(!$NoQuestion){&$ChangeDetails}




while($true){

            $PipelinesToPauseResume=@()

            Write-Host 'How you want to choose pipelines'
            Write-Host '1. By exact name'
            Write-Host '2. Pipelines starts with'
            Write-Host '3. All the pipelines in the Data Factory'
            Write-Host '4. Exit'

            $input=Read-Host 'Enter the input(1/2/3/4)':
            if($input -eq 4){Return}


            #region By exact name
            if($input -eq 1)
            {
            $name=Read-Host -Prompt "Enter the exact name(Press just enter to go back)"

            if(!$name){continue}
            Try
            {
            $AllPipelines=Get-AzureRmDataFactoryPipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $name
            $AllPipelines|Select-Object -ExpandProperty Properties
            }
            Catch
            {            {
            Write-Host  'Pipeline Not Found,check the details entered' -ForegroundColor Red
            continue
            }

            $PipelinesToPauseResume+=$AllPipelines

            }
            }
            #endregion



            try
            {
            $AllPipelines=Get-AzureRmDataFactoryPipeline  -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName
            }catch
            {
            Write-Host 'Something wrong happended check the details entered' `n $Error -ForegroundColor Red
            continue
            }


            #region Pipelines starts with
            if($input -eq 2)
            {
            $name='CRMService_EDH_SQLDW_'
            $prompt=Read-Host -Prompt "Pipeline Starts with(Press enter to accept the default) [$($name)]"
            $name = ($name,$prompt)[[bool]$prompt]

            foreach($pipeline in $AllPipelines){
            if($pipeline.PipelineName.StartsWith($name)){
            #$PipelinesToPauseResume+=$pipeline;
                }
            }


            }

            #endregion


            #region All the pipelines in the Data Factory
            elseif($input -eq 3)
            {
            Write-host 'Not implemented'
            continue
            #$PipelinesToPauseResume=$AllPipelines;
            }

            #endregion


            #Display all the afecting pipelines
            Write-Host 'Pipelines going to affect'
            $PipelinesToPauseResume|Format-Table @{Label='Pipeline Name';Expression={$_.PipelineName}}, @{ Label = "Is Paused"; Expression={$_.Properties.IsPaused}}


            #region Pause choosen Pipelines
            if($Pause -like 'true'){

            Write-host 'Pausing the Pipelines..............' -ForegroundColor DarkMagenta
            foreach($pipeline in $PipelinesToPauseResume){
            $result=$false
            try{
            $result=Suspend-AzureRmDataFactoryPipeline -DataFactoryName $DataFactoryName -Name $pipeline.PipelineName -ResourceGroupName $ResourceGroupName 
            if($result){write-host $pipeline.PipelineName 'Paused' -ForegroundColor Green}
            else{write-host $pipeline.PipelineName 'Pausing failed' -ForegroundColor red}

            }catch{
            write-host $pipeline.PipelineName 'Pausing failed' -ForegroundColor red
            }

            }

            }

            #endregion

            #region Resume selected Pipelines
            elseif($Pause -like 'false')
            {
            $NewStartTime=(Get-Date).ToUniversalTime()# -format G)
            $prompt=Read-Host -Prompt "New Start date for the pipelines(Press enter to accept the default,0 not to change the startdate) [$($NewStartTime)]"
            $NewStartTime = ($NewStartTime,$prompt)[[bool]$prompt]



            Write-host 'Resuming the Pipelines..............' -ForegroundColor DarkMagenta
            foreach($pipeline in $PipelinesToPauseResume){
            $result=$false
            try{
                $result=Resume-AzureRmDataFactoryPipeline -DataFactoryName $DataFactoryName -Name $pipeline.PipelineName -ResourceGroupName $ResourceGroupName 
            if(!$result){write-host $pipeline.PipelineName 'Resuming failed' -ForegroundColor red
            continue}
            write-host $pipeline.PipelineName 'Resuming successed' -ForegroundColor Green

            $result=Set-AzureRmDataFactoryPipelineActivePeriod -DataFactoryName $DataFactoryName -PipelineName $pipeline.PipelineName -ResourceGroupName $ResourceGroupName -StartDateTime $NewStartTime
            if($result){write-host $pipeline.PipelineName 'startTime changed' -ForegroundColor Green}
            else{write-host $pipeline.PipelineName 'startTime change failed' -ForegroundColor Cyan
            continue}


            }
            catch{
            write-host $pipeline.PipelineName 'Resuming failed ' -ForegroundColor red
            }

            }
            }

            #endregion

            Write-Host 'Task Completed' -ForegroundColor yellow

         }







