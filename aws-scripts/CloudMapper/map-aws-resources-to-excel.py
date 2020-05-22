import xlsxwriter
import subprocess
import re

list_of_arns = []
arn_values_sizes = []
pattern = r'\b\d{12}'  #the regex value for the aws account id which has 12 digits
filepath = 'aws_tagged_resources.txt'

def getMinMax(low, high, arr): 
    arr_max = arr[low] 
    arr_min = arr[low] 
      
    # If there is only one element  
    if low == high: 
        arr_max = arr[low] 
        arr_min = arr[low] 
        return (arr_max, arr_min) 
          
    # If there is only two element 
    elif high == low + 1: 
        if arr[low] > arr[high]: 
            arr_max = arr[low] 
            arr_min = arr[high] 
        else: 
            arr_max = arr[high] 
            arr_min = arr[low] 
        return (arr_max, arr_min) 
    else: 
          
        # If there are more than 2 elements 
        mid = int((low + high) / 2) 
        arr_max1, arr_min1 = getMinMax(low, mid, arr) 
        arr_max2, arr_min2 = getMinMax(mid + 1, high, arr) 
  
    return (max(arr_max1, arr_max2), min(arr_min1, arr_min2)) 

def arnFormattingFile():
    with open(filepath) as fp:
        line = fp.readline()
        formatReadLinesIntoArn(line, fp)

def formatReadLinesIntoArn(line, fp):
    cnt = 1
    while line:
        print("Line {}: {}".format(cnt, line.strip()))
        arn_values = formatArnValues(line)
        splitAndFormatArnValues(arn_values)
        list_of_arns.append(arn_values)
        line = fp.readline()
        cnt += 1  

def formatArnValues(line):
    arn_values = line.split(':')
    aws_id = [x for x in arn_values if re.search(pattern, x)]
    arn_values = [x for x in arn_values if x != 'aws' and x != 'arn' and not re.search(pattern, x)]
    arn_values.extend(aws_id)
    arn_values = [x.rstrip('\n') for x in arn_values]
    print(arn_values)
    arn_values_sizes.append(len(arn_values))
    return arn_values

def splitAndFormatArnValues(arn_values):
    if("/" in arn_values[2]):
        arn_split = arn_values[2].split("/")
        arn_service = arn_split[0]
        arn_split.remove(arn_split[0])
        arn_source = "/".join(arn_split)
        print(f"arn source from split: {arn_source}")
        arn_values.remove(arn_values[2])
        arn_values.insert(2, arn_service)
        arn_values.insert(3, arn_source)

def parseArnValues(list_of_arns, pattern):
    for arn_values in list_of_arns:
        if(len(arn_values) < arr_max):
            arn_values_diff = arr_max-len(arn_values)
            for _ in range(arn_values_diff):
                if (re.search(pattern,arn_values[len(arn_values)-1])):
                    arn_values.insert(len(arn_values)-1,'')
                elif(re.search(pattern,arn_values[arn_values_diff])):
                    arn_values.insert(arn_values_diff,len(arn_values)-1)
        print(f'refactored values:{arn_values}')

def mapArnListToXls(list_of_arns,worksheet):
    list_of_arns=(list_of_arns)
    charA=64
    for row in range(len(list_of_arns)):
        #print('\n')
        for column in range(len(list_of_arns[row])):
           # print(f'cell:{chr(charA+column+1)}{row+1}::-> {list_of_arns[row][column]}')
            worksheet.write(row +1, column, list_of_arns[row][column])

##########MAIN PROGRAM###########
#list_files = subprocess.run(["sh", "list-aws-resources.sh"])
#print("The exit code was: %d" % list_files.returncode)

workbook = xlsxwriter.Workbook('aws_resources.xlsx') 
worksheet = workbook.add_worksheet('tagged_resources') 

arnFormattingFile()

print(f'arn_values_sizes:{arn_values_sizes}')
high = len(arn_values_sizes) - 1
low = 0
arr_max, arr_min = getMinMax(low, high, arn_values_sizes)
print('Minimum element is ', arr_min)
print('nMaximum element is ', arr_max)
parseArnValues(list_of_arns, pattern)
print(f'current resources: rows:{len(list_of_arns)},numcols:{len(list_of_arns[0])}')

mapArnListToXls(list_of_arns, worksheet)
options = {'style': 'Table Style Light 11',
           'columns': [{'header': 'Service'},
                       {'header': 'Region'},
                       {'header': 'Service_name'},
                       {'header': 'Service_source'},
                       {'header': 'Service_metadata'},
                       {'header': 'AccountID'},
                       ]
           }
worksheet.add_table(0, 0, len(list_of_arns), len(list_of_arns[0])-1, options)
workbook.close()

