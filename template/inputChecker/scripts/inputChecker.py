# -*- coding: utf-8 -*-
"""
Southern Oregon ABM Input Checker

    script to review all inputs to SOABM for possible issues that will result in model errors
    script exports CSV tables from the input version file
    script also exports all other inputs as required for CTRAMP
    finally, list of checks are read from a CSV settings file
    CSV checker module goes through the list of tests
    input test expression should evaluate to True or False or a list of True/False values for each
    row in the table to which the test was applied to
    a log file is produced at the end with results of each test

Feb 2018
@author: binny.mathewpaul@rsginc.com
"""

########################################################################################################################
# IMPORT LIBRARIES
########################################################################################################################

import os, shutil, sys, time, csv, logging
#sys.path.append("C:/Program Files/PTV Vision/PTV Visum 2020/Exe/Python37Modules")
sys.path.append("C:/Program Files/PTV Vision/PTV Visum 2020/Exe/Python37Modules/Lib/site-packages")
import win32com.client as com
import VisumPy.helpers
import numpy as np
import pandas as pd
import VisumPy.csvHelpers
import traceback
import datetime
import openmatrix as omx

########################################################################################################################
# DEFINE FUNCTIONS
########################################################################################################################

def startVisum():
  print("start Visum")
  Visum = VisumPy.helpers.CreateVisum(20)
  pathNo = [8,69,2,37,12]
  for i in range(0,len(pathNo)): 
    Visum.SetPath(pathNo[i], os.getcwd())
  return(Visum)
  
def loadVersion(Visum, fileName):
  print("load version file: " + fileName)
  Visum.LoadVersion(fileName)

def saveVersion(Visum, fileName):
  print("save version file: " + fileName)
  Visum.SaveVersion(fileName)

def closeVisum(Visum):
  print("close Visum")
  Visum = None

def str_to_bool(s):
    if (s == 'True') | (s == 'TRUE') | (s == 'true'):
         return True
    elif (s == 'False') | (s == 'FALSE') | (s == 'false'):
         return False
    else:
         raise ValueError

def export_csv(Visum, visum_obj, fieldsToExport, csv_name):
    # function to get Visum object property map = _prop_map_get_
#   for now user is expected ti provide all the fields to export    
#    if fieldsToExport[0]=='All':
#        visum_expr1 = visum_obj + '.Attributes.GetAll'
#        obj_attributes = eval(visum_expr1)
#        fieldsToExport = []
#        for i in obj_attributes:
#            fieldsToExport.append(i.ID)
            
    #create header
    header = ",".join(fieldsToExport)
    
    #create rows
    row = []
    for i in range(len(fieldsToExport)):
        visum_expr2 = 'VisumPy.helpers.GetMulti(' + visum_obj + ', fieldsToExport[' + str(i) + '])'
        uda = eval(visum_expr2)
        if i==0:
            for j in range(len(uda)):
                #for strings with "," enclose in quotes
                if "," in str(uda[j]):
                    row.append('"' + str(uda[j]) + '"')
                else:
                    row.append(str(uda[j]))
        else:
            for j in range(len(uda)):
                #for strings with "," enclose in quotes
                if "," in str(uda[j]):
                    row[j] = row[j] + "," + '"' + str(uda[j]) + '"'
                else:
                    row[j] = row[j] + "," + str(uda[j])
                
        
    #create output file
    f = open(os.path.join(cwd,'inputs',csv_name + '.csv'), 'w', newline='\n')
    f.write(header + "\r\n")
    for i in range(len(row)):
        f.write(row[i] + "\r\n")
    f.close()
    
def write_log(results, problem_ids, checks_list, inputs_list, result_list, settings, report_stat):
    # function to write out the input checker log file
    # There are three blocks
    #   - Introduction
    #   - Action Required: FATAL, LOGICAL, WARNINGS
    #   - List of passed checks
    
    # Create log file
    now = datetime.datetime.now()
    f = open(os.path.join(cwd,'logs', ('inputCheckerLog ' + now.strftime("[%Y-%m-%d]") + '.LOG')), 'w')
    
    # Define re-usable elements
    seperator1 = '###########################################################'
    seperator2 = '***********************************************************'
    
    # Write out Header
    f.write(seperator1 + seperator1 + "\r\n")
    f.write(seperator1 + seperator1 + "\r\n\r\n")
    f.write("\t SOABM Input Checker Log File \r\n")
    f.write("\t ____________________________ \r\n\r\n\r\n")
    f.write("\t Log created on: " + now.strftime("%Y-%m-%d %H:%M") + "\r\n\r\n")
    f.write("\t Notes:-\r\n")
    f.write("\t The SOABM Input Checker performs various QA/QC checks on SOABM inputs as specified by the user.\r\n")
    f.write("\t The Input Checker allows the user to specify three severity levels for each QA/QC check:\r\n\r\n")
    f.write("\t 1) FATAL  2) LOGICAL  3) WARNING\r\n\r\n")
    f.write("\t FATAL Checks:   The failure of these checks would result in a FATAL errors in the SOABM run.\r\n")
    f.write("\t                 In case of FATAL failure, the Input Checker returns a return code of 1 to the\r\n")
    f.write("\t                 main SOABM model, cauing the model run to halt.\r\n")
    f.write("\t LOGICAL Checks: The failure of these checks indicate logical inconsistencies in the inputs.\r\n")
    f.write("\t                 With logical errors in inputs, the SOABM outputs may not be meaningful.\r\n")
    f.write("\t WARNING Checks: The failure of Warning checks would indicate problems in data that would not.\r\n")
    f.write("\t                 halt the run or affect model outputs but might indicate an issue with inputs.\r\n\r\n\r\n")
    f.write("\t The results of all the checks are organized as follows: \r\n\r\n")
    f.write("\t IMMEDIATE ACTION REQUIRED:\r\n")
    f.write("\t -------------------------\r\n")
    f.write("\t A log under this heading will be generated in case of failure of a FATAL check\r\n\r\n")
    f.write("\t ACTION REQUIRED:\r\n")
    f.write("\t ---------------\r\n")
    f.write("\t A log under this heading will be generated in case of failure of a LOGICAL check\r\n\r\n")
    f.write("\t WARNINGS:\r\n")
    f.write("\t ---------------\r\n")
    f.write("\t A log under this heading will be generated in case of failure of a WARNING check\r\n\r\n")
    f.write("\t MISSING VALUE SELF DIAGNOSTICS:\r\n")
    f.write("\t -----------\r\n")
    f.write("\t A complete listing of failed missing value self diagnostics tests on all inputs\r\n\r\n")
    f.write("\t LOG OF ALL PASSED CHECKS:\r\n")
    f.write("\t -----------\r\n")
    f.write("\t A complete listing of results of all passed checks\r\n\r\n")
    f.write(seperator1 + seperator1 + "\r\n")
    f.write(seperator1 + seperator1 + "\r\n\r\n\r\n\r\n")
    
    # Combine results, checks_list and inputs_list
    checks_list['result'] = checks_list['Test'].map(results)
    checks_df = pd.merge(checks_list, inputs_list, on='Input_Table')
    checks_df = checks_df[checks_df.Type=='Test']
    checks_df['reverse_result'] = [not i for i in checks_df.result]
    
    # Get all FATAL failures
    num_fatal = checks_df.result[(checks_df.Severity=='Fatal') & (checks_df.reverse_result)].count()
    
    # Get all LOGICAL failures
    num_logical = checks_df.result[(checks_df.Severity=='Logical') & (checks_df.reverse_result)].count()
    
    # Get all WARNING failures
    num_warning = checks_df.result[(checks_df.Severity=='Warning') & (checks_df.reverse_result)].count()
    
    # Write out IMMEDIATE ACTION REQUIRED section if needed
    if num_fatal>0:
        fatal_checks = checks_df[(checks_df.Severity=='Fatal') & (checks_df.reverse_result)]
        f.write('\r\n\r\n' + seperator2 + seperator2 + "\r\n")
        f.write(seperator2 + seperator2 + "\r\n\r\n")
        f.write('\t' + "IMMEDIATE ACTION REQUIRED \r\n")
        f.write('\t' + "------------------------- \r\n\r\n")
        f.write(seperator2 + seperator2 + "\r\n")
        f.write(seperator2 + seperator2 + "\r\n")
        
        #write out log for each check
        for item, row in fatal_checks.iterrows():
            write_check_log(f, row, problem_ids[row['Test']], result_list, report_stat)
    
    # Write out ACTION REQUIRED section if needed
    if num_logical>0:
        logical_checks = checks_df[(checks_df.Severity=='Logical') & (checks_df.reverse_result)]
        f.write('\r\n\r\n' + seperator2 + seperator2 + "\r\n")
        f.write(seperator2 + seperator2 + "\r\n\r\n")
        f.write('\t' + "ACTION REQUIRED \r\n")
        f.write('\t' + "--------------- \r\n\r\n")
        f.write(seperator2 + seperator2 + "\r\n")
        f.write(seperator2 + seperator2 + "\r\n")
        
        #write out log for each check
        for item, row in logical_checks.iterrows():
            write_check_log(f, row, problem_ids[row['Test']], result_list, report_stat)
    
    # Write out WARNINGS section if needed
    if num_warning>0:
        warning_checks = checks_df[(checks_df.Severity=='Warning') & (checks_df.reverse_result)]
        f.write('\r\n\r\n' + seperator2 + seperator2 + "\r\n")
        f.write(seperator2 + seperator2 + "\r\n\r\n")
        f.write('\t' + "WARNINGS \r\n")
        f.write('\t' + "-------- \r\n")
        f.write(seperator2 + seperator2 + "\r\n")
        f.write(seperator2 + seperator2 + "\r\n")
        
        #write out log for each check
        for item, row in warning_checks.iterrows():
            write_check_log(f, row, problem_ids[row['Test']], result_list, report_stat)
    
    # Do self diagnostics on all inputs
    #  - check for presence of NAs in all columns and raise flag as per severity level  in settings file
    f.write('\r\n\r\n' + seperator2 + seperator2 + "\r\n")
    f.write(seperator2 + seperator2 + "\r\n\r\n")
    f.write('\t' + "MISSING VALUE DIAGNOSTICS ON ALL INPUTS \r\n")
    f.write('\t' + "--------------------------------------- \r\n\r\n")
    f.write('\t' + "Only failed checks are printed \r\n")
    f.write(seperator2 + seperator2 + "\r\n")
    f.write(seperator2 + seperator2 + "\r\n")
    
    for item, row in inputs_list.iterrows():
        # read the input dataframe
        #row=inputs_list.iloc[8]
        table_name = row['Input_Table']
        df = inputs[table_name]
        
        #replace all 'None' with nan
        df.replace('None', np.nan)
        
        #go through every column of the dataframe
        for column in df:
            #convert all none in the column to NaN
            expr1 = 'df["' + column + '"] = df["' + column + '"].apply(lambda x: np.nan if x=="None" else x)'
            exec(expr1)
            # create a self diagnostic test for the column
            column_test = {}
            column_test['Test'] = 'Self Diagnostic: Missing values in ' + column
            column_test['Input_Table'] = row['Input_Table']
            column_test['Input_Filename'] = row['Input_Filename']
            column_test['ID_Column'] = row['Input_ID_Column']
            column_test['Severity'] = settings['self_diagnostic_na_severity']
            column_test['Type'] = 'Test'
            column_test['Test_Vals'] = np.NaN
            column_test['Report_Statistic'] = np.NaN
            column_test['Test_Description'] = 'Check for missing values in ' + column + ' field of ' + table_name 
            
            #from input list
            column_test['Visum_Object'] = row['Visum_Object']
            column_test['Fields'] = row['Fields']
            column_test['Input_Description'] = row['Input_Description']
            
            #perform test and get result
            #expr = 'df[["' + column + '"]].isnull().' + column
            expr = 'pd.isnull(df.loc[:,"' + column + '"])'
            out = eval(expr)
            # Tests must evaluate to True
            out = ~out
            
            # check if test result is a series
            if str(type(out))=="<class 'pandas.core.series.Series'>":
                # for series the test must be evaluated across all items
                # results is false even if a single False is found
                column_test['result'] = not (False in out.values)
                # reverse results list [since we need all False IDs]
                reverse_results = [not i for i in out.values]
                error_expr = column_test['Input_Table'] + "." + column_test['ID_Column'] + "[reverse_results]"
                error_id_list = eval(error_expr)
                # report first 25 roblem IDs in the log
                if error_id_list.size>25:
                    problem_id_list = error_id_list.iloc[range(25)]
                else:
                    problem_id_list = error_id_list if error_id_list.size>0 else []
            else:
                column_test['result'] = out
                problem_id_list = []
                
            # write log if the check failed
            if not column_test['result']:
                write_check_log(f, column_test, problem_id_list, result_list, report_stat)
            
            #print 'here' + column_test['Test']
            
    # Write out the complete listing of all checks that passed
    passed_checks = checks_df[(checks_df.result)]
    f.write('\r\n\r\n' + seperator2 + seperator2 + "\r\n")
    f.write(seperator2 + seperator2 + "\r\n\r\n")
    f.write('\t' + "LOG OF ALL PASSED CHECKS \r\n")
    f.write('\t' + "------------------------ \r\n")
    f.write(seperator2 + seperator2 + "\r\n")
    f.write(seperator2 + seperator2 + "\r\n")
    
    #write out log for each check
    for item, row in passed_checks.iterrows():
        write_check_log(f, row, problem_ids[row['Test']], result_list, report_stat)
        

        
    f.close()
    # Write out a summary of results from input checker for main model
    f = open(os.path.join(cwd,'logs', ('inputCheckerSummary' + '.txt')), 'w')
    f.write('\r\n' + seperator2 + '\r\n')
    f.write('\t Summary of Input Checker Fails \r\n')
    f.write(seperator2 + '\r\n\r\n')
    f.write(' Number of Fatal Errors: ' + str(num_fatal))
    f.write('\r\n\r\n Number of Logical Errors: ' + str(num_logical))
    f.write('\r\n\r\n Number of Warnings: ' + str(num_warning) + '\r\n\r\n')
    f.close()
    return(num_fatal)
    

def write_check_log(fh, row, problem_ids, result_list, report_stat):
    # Define constants
    seperator2 = '-----------------------------------------------------------'
    cwd = os.getcwd()
    #print(row['Test'])
    # Integerize problem ID list
    problem_ids = [int(x) for x in problem_ids]
    # Write check summary
    fh.write('\r\n\r\n' + seperator2 + seperator2)
    fh.write("\r\n\t Input File Name: " + row['Input_Filename'] + '.csv')
    fh.write("\r\n\t Input File Location: " + cwd + ('Input Visum Version File' if not pd.isnull(row['Visum_Object']) else ('\\inputs\\' + row['Input_Filename'] + '.csv')))
    fh.write("\r\n\t Visum Object: " + (row['Visum_Object'] if not pd.isnull(row['Visum_Object']) else 'NA'))
    fh.write("\r\n\t Input Description: " + (row['Input_Description'] if not pd.isnull(row['Input_Description']) else ""))
    fh.write("\r\n\t Test Name: " + row['Test'])
    fh.write("\r\n\t Test Description: " + (row['Test_Description'] if not pd.isnull(row['Test_Description']) else ""))
    fh.write("\r\n\t Test Severity: " + row['Severity'])
    fh.write("\r\n\r\n\t TEST RESULT: " + ('PASSED' if row['result'] else 'FAILED'))
    # Display problem IDs for failed column checks
    if (not row['result']) & (len(problem_ids)>0) :
        fh.write("\r\n\t TEST failed for following values of ID Column: " + row['ID_Column'] + " (only upto 25 IDs displayed)")
        fh.write("\r\n\t " + row['ID_Column'] + ": " + ','.join(map(str, problem_ids[0:25])))
        if not (pd.isnull(row['Report_Statistic'])):
            report_stat = report_stat[row['Test']]
            fh.write("\r\n\t Test Statistics: " + ','.join(map(str, report_stat[0:25])))
        fh.write("\r\n\t Total number of failures: " + str(len(problem_ids)))
    else:
        if not (pd.isnull(row['Report_Statistic'])):
            fh.write("\r\n\t Test Statistic: " + str(report_stat[row['Test']]))
    # Display result for each test val if it was specified
    if not (pd.isnull(row['Test_Vals'])):
        fh.write("\r\n\t TEST results for each test val")
        result_tuples = zip(row['Test_Vals'].split(","), result_list[row['Test']])
        fh.write("\r\n\t ")
        fh.write(','.join('[{} - {}]'.format(x[0],x[1]) for x in result_tuples))
        
    fh.write("\r\n" + seperator2 + seperator2 + "\r\n\r\n")
    
    
    



########################################################################################################################
# STARTING MODULE
########################################################################################################################

if __name__== "__main__":
    
    try:
                
        print("input checker started at: " + time.ctime())
        working_dir = sys.argv[1]
        #working_dir = 'E:/projects/clients/odot/SouthernOregonABM/Contingency/TransitEverywhere/FinalTest/SOABM/template/inputChecker'
        os.chdir(working_dir)
        cwd = os.getcwd()
        
        # Read settings file
        print("reading input checks list")
        checks_list = pd.read_csv(os.path.join(cwd,'config','inputs_checks.csv'), encoding='cp1252')
        inputs_list = pd.read_csv(os.path.join(cwd,'config','inputs_list.csv'), encoding='cp1252')
        settings_df = pd.read_csv(os.path.join(cwd,'config','settings.csv'), encoding='cp1252')
        
        #get all settings
        settings = {}
        settings['self_diagnostic_na_severity'] = settings_df.value[settings_df['token'] == 'self_diagnostic_na_severity'].iloc[0]
        settings['input_version_file'] = settings_df.value[settings_df['token'] == 'input_version_file'].iloc[0]
        
        # Read in all inputs as dict of DFs (Export files that need to be exported)
        export_Visum = True
        if export_Visum:
            Visum = startVisum()
            loadVersion(Visum, os.path.join(cwd,'..','inputs',settings['input_version_file']))
        
        # Remove all commented checks from the checks list
        inputs_list = inputs_list.loc[[not i for i in (inputs_list['Input_Table'].str.startswith('#'))]]
                                                       
        inputs = {}
        for item, row in inputs_list.iterrows():
            
            #row = inputs_list.iloc[0]
            print('Adding ' + row['Input_Table'])
            csv_name = row['Input_Filename']
            table_name = row['Input_Table']
            directory = row['Input_Directory']
            visum_obj = row['Visum_Object']
            columnMap = row['Column_Map']
            inputIDColumn = row['Input_ID_Column']
            fieldsToExport = row['Fields'].split(",")
            
            # export the visum table and read other csv inputs
            if not (pd.isnull(visum_obj)) :
                if export_Visum:
                    export_csv(Visum, visum_obj, fieldsToExport, csv_name)
                
                df = pd.read_csv(os.path.join(cwd,'inputs',csv_name + '.csv'))
                #if ID column does not exist, cerate as DF index
                if not (inputIDColumn in df.columns):
                    df[inputIDColumn] = df.index.values
                #rename columns if a map was specified
                if not (pd.isnull(columnMap)):
                   rename_expr = 'df.rename(columns=' + columnMap + ', inplace=True)'
                   exec(rename_expr)
                inputs[table_name] = df
            else:
                # CSV inputs can be in both inputs or uec directory
                if directory == 'inputs':
                    df = pd.read_csv(os.path.join(cwd,'..','inputs',csv_name + '.csv'))
                else:
                    df = pd.read_csv(os.path.join(cwd,'..','uec',csv_name + '.csv'))
                    
                df.to_csv(os.path.join(cwd,'inputs',csv_name + '.csv'))
                #if ID column does not exist, cerate as DF index
                if not (inputIDColumn in df.columns):
                    df[inputIDColumn] = df.index.values
                #rename columns if a map was specified
                if not (pd.isnull(columnMap)):
                   rename_expr = 'df.rename(columns=' + columnMap + ', inplace=True)'
                   exec(rename_expr)
                print(table_name)   
                inputs[table_name] = df
                
            
        if export_Visum:
            del Visum
        
        # Read all input DFs into memory
        for key, df in inputs.items():
            expr = key + ' = df'
            exec(expr)
            
                    
        # Remove all commented checks from the checks list
        checks_list = checks_list.loc[[not i for i in (checks_list['Test'].str.startswith('#'))]]
                                                       
        # Loop throgh settings file and do all the checks
        # [checks must evaluate to True if inputs are correct]
        results = {}
        result_list = {}
        problem_ids = {}
        report_stat = {}
        for item, row in checks_list.iterrows():
            
            #row = checks_list.iloc[0]
            
            test = row['Test']
            table = row['Input_Table']
            id_col = row['ID_Column']
            expr = row['Expression']
            test_vals = row['Test_Vals']
            if not (pd.isnull(row['Test_Vals'])):
                test_vals = test_vals.split(",")
                test_vals = [txt.strip() for txt in test_vals]
            test_type = row['Type']
            Severity = row['Severity']
            stat_expr = row['Report_Statistic']
            
            if test_type == 'Test':
                print('Performing check: ' + row['Test'])
                if (pd.isnull(row['Test_Vals'])):
                    
                    # perform test
                    out = eval(expr)
                    
                    # check if test result is a series
                    if str(type(out))=="<class 'pandas.core.series.Series'>":
                        # for series the test must be evaluated across all items
                        # results is false even if a single False is found
                        results[test] = not (False in out.values)
                        # reverse results list [since we need all False IDs]
                        reverse_results = [not i for i in out.values]
                        error_expr = table + "." + id_col + "[reverse_results]"
                        error_id_list = eval(error_expr)
                        # report first 25 problem IDs in the log
                        problem_ids[test] = error_id_list if error_id_list.size>0 else []
                        # compute report statistic
                        if (pd.isnull(stat_expr)):
                            report_stat[test] = ''
                        else:
                            stat_list = eval(stat_expr)
                            report_stat[test] = stat_list[reverse_results]
#                        if error_id_list.size>25:
#                            problem_ids[test] = error_id_list.iloc[range(25)]
#                        else:
#                            problem_ids[test] = error_id_list if error_id_list.size>0 else []
                    else:
                        results[test] = out
                        problem_ids[test] = []
                        if (pd.isnull(stat_expr)):
                            report_stat[test] = ''
                        else:
                            report_stat[test] = eval(stat_expr)
                else:
                    # loop through test_vals and perform test for each test_val
                    result_list[test] = []
                    for test_val in test_vals:
                        # perform test [The tests must not result in series]
                        out = eval(expr)
                        # compute report statistic
                        if (pd.isnull(stat_expr)):
                            report_stat[test] = ''
                        else:
                            report_stat[test] = eval(stat_expr)
                        # append to list
                        result_list[test].append(out)
                    results[test] = not (False in result_list[test])
                    problem_ids[test] = []
                           
                
            else:
                # perform calculation
                print('Performing calculation: ' + row['Test'])
                calc_expr = test + ' = ' + expr
                exec(calc_expr)
            
        
        # Write out log file
        print("\r\nWriting log file\r\n")
        num_fatal = write_log(results, problem_ids, checks_list, inputs_list, result_list, settings, report_stat)
        
        # Return code to the main model based on input checks and results
        if num_fatal >0:
            print("at least one fatal error in the inputs")
            sys.exit(2)
            
        
        
        print("input checker finished at: " + time.ctime())
    
    except Exception as e:
        print("Input Checker Failed") 
        print(e)
        sys.exit(1)

#finish