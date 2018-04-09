
#Southern Oregon ABM VISUM Functions
#Ben Stabler, ben.stabler@rsginc.com, 04/06/15
#Requires the OMX Import/Export Add-In to be installed

#"C:\Program Files\Python27\python.exe" scripts\SOABM.py taz_initial
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py maz_initial
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py tap_initial
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py maz_skim
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py taz_skim_speed
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py tap_skim_speed
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py build_trip_matrices 1.0 1
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py taz_skim
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py tap_skim
#"C:\Program Files\Python27\python.exe" scripts\SOABM.py generate_html_inputs

############################################################

#import libraries
import os, shutil, sys, time, csv
sys.path.append("C:/Program Files/PTV Vision/PTV Visum 16/Exe/PythonModules")
import win32com.client as com
import VisumPy.helpers, omx, numpy
import VisumPy.csvHelpers
import traceback

############################################################

def startVisum():
  print("start Visum")
  Visum = VisumPy.helpers.CreateVisum(16)
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

def loadProcedure(Visum,parFileName,execute=True):
  print("run procedure file: " + parFileName)
  Visum.Procedures.Open(parFileName)
  if execute:
    Visum.Procedures.Execute()

def removeAllMatrices(Visum):
  matrixIds = Visum.Net.Matrices.GetMultiAttValues("No")
  matrixNames = Visum.Net.Matrices.GetMultiAttValues("NAME")
  for Id in matrixIds.keys():
    Visum.Net.RemoveMatrix(Visum.Net.Matrices.ItemByKey(Id[1]))

def calcDist(x1,x2,y1,y2):
  return(((x1-x2)**2 + (y1-y2)**2)**0.5)
  
def getClosestN(from_x,from_y,to_ids,to_xs,to_ys,n):
  nearest = [(-1,999999999)]*n #list of tuples of node id and distance
  for k in range(len(to_ids)):
    dist = calcDist(from_x, to_xs[k], from_y, to_ys[k])
    if dist < max([near[1] for near in nearest]):
      nearest[n-1] = (to_ids[k],dist)
      nearest.sort(key=lambda x: x[1])
  return([near[0] for near in nearest])

def getCandidateNodesForConnectors(Visum, facTypeList):
  
  nodeNo       =  VisumPy.helpers.GetMulti(Visum.Net.Nodes, "No", False)
  nodeFTs      =  VisumPy.helpers.GetMulti(Visum.Net.Nodes, "Concatenate:OutLinks\PLANNO", False)
  nodeX        =  VisumPy.helpers.GetMulti(Visum.Net.Nodes, "XCoord", False)
  nodeY        =  VisumPy.helpers.GetMulti(Visum.Net.Nodes, "YCoord", False)
  nodeCandidate=  [False] * len(nodeY) #will be calculated below

  for i in range(len(nodeNo)):
    for j in nodeFTs[i].split(","):
      if j not in facTypeList:
        nodeCandidate[i] = False
      else:
        nodeCandidate[i] = True
  
  nodeNo_out = [] 
  nodeX_out =  []
  nodeY_out =  []
  
  for i in range(len(nodeNo)):
    if nodeCandidate[i]:
      nodeNo_out.append(nodeNo[i])
      nodeX_out.append(nodeX[i])
      nodeY_out.append(nodeY[i])
  
  return(nodeNo_out, nodeX_out, nodeY_out)

def codeTAZConnectors(Visum):
  
  #TAZ connector speeds and delete connector if too close distance
  defaultSpeed = 25
  tooCloseDistFeet = 500
  internalTazStart = 100
  
  #get candidate nodes
  print('get candidate nodes')
  nodeNo, nodeX, nodeY = getCandidateNodesForConnectors(Visum,['3','4','5','6'])

  #assign to nearest and create connector
  print('assign tazs to nearest nodes and create connectors')
  Visum.Graphic.StopDrawing=True
  zoneIds = Visum.Net.Zones.GetMultiAttValues("No")
  zoneXs = Visum.Net.Zones.GetMultiAttValues("Xcoord")
  zoneYs = Visum.Net.Zones.GetMultiAttValues("Ycoord")

  for i in range(len(zoneIds)):
    if zoneIds[i][1] >= internalTazStart:
      zoneObj = Visum.Net.Zones.ItemByKey(zoneIds[i][1])
      nodeids = getClosestN(zoneXs[i][1], zoneYs[i][1], nodeNo, nodeX, nodeY, 4)
      for j in range(len(nodeids)):
        nodeObj = Visum.Net.Nodes.ItemByKey(nodeids[j])
        if not Visum.Net.Connectors.ExistsByKey(nodeObj, zoneObj):
        
          conObj = Visum.Net.AddConnector(zoneObj, nodeObj)
          lenMiles = conObj.AttValue("Length")
          for mode in ['SOV','SOVToll','HOV2','HOV2Toll','HOV3','HOV3Toll','Truck','TruckToll']:
            conObj.SetAttValue("T0_TSys(" + mode + ")",lenMiles * (60.0 / defaultSpeed) * 60)
        
          conObj = Visum.Net.Connectors.DestItemByKey(nodeObj, zoneObj)
          lenMiles = conObj.AttValue("Length")
          for mode in ['SOV','SOVToll','HOV2','HOV2Toll','HOV3','HOV3Toll','Truck','TruckToll']:
            conObj.SetAttValue("T0_TSys(" + mode + ")",lenMiles * (60.0 / defaultSpeed) * 60)
  
  #delete connectors if too close to one another
  print('delete connectors if too close to one another')
  for i in range(len(zoneIds)):
    zoneObj = Visum.Net.Zones.ItemByKey(zoneIds[i][1])
    nodeNos = zoneObj.AttValue("Concatenate:OrigConnectors\Node\No")
    nodeXs = zoneObj.AttValue("Concatenate:OrigConnectors\Node\XCoord")
    nodeYs = zoneObj.AttValue("Concatenate:OrigConnectors\Node\YCoord")
    nodeNos = map(int,nodeNos.split(","))
    nodeXs = map(float,nodeXs.split(","))
    nodeYs = map(float,nodeYs.split(","))
    
    for j in range(len(nodeNos)):
      if j == 0:
        previous_x = nodeXs[j]
        previous_y = nodeYs[j] 
      else:
        if calcDist(nodeXs[j],previous_x,nodeYs[j],previous_y) < tooCloseDistFeet:
          nodeObj = Visum.Net.Nodes.ItemByKey(nodeNos[j])
          conObj = Visum.Net.Connectors.SourceItemByKey(zoneObj, nodeObj)
          Visum.Net.RemoveConnector(conObj)
        previous_x = nodeXs[j]
        previous_y = nodeYs[j]
  
  Visum.Graphic.StopDrawing=False
  
def switchZoneSystem(Visum, zoneSystem):
  
  #walk connector speeds for time calculation
  defaultWalkSpeed = 3
  
  Visum.Graphic.StopDrawing=True
  
  #remove TAZs
  print("remove tazs")
  zoneIds = Visum.Net.Zones.GetMultiAttValues("No")
  for Id in zoneIds:
    Visum.Net.RemoveZone(Visum.Net.Zones.ItemByKey(Id[1]))
  
  print("remove taz UDAs")
  for i in Visum.Net.Zones.Attributes.GetAll:
    if i.category=="User-defined attributes":
      Visum.Net.Zones.DeleteUserDefinedAttribute(i.Name)
  
  #mazs from mainzones to tazs
  if zoneSystem=="maz":
    print("mazs from mainzones to tazs")
    
    #move mainzone UDAs to taz UDAs
    print("move mainzone UDAs to taz UDAs")
    for i in Visum.Net.MainZones.Attributes.GetAll:
      if i.category=="User-defined attributes":
        Visum.Net.Zones.AddUserDefinedAttribute(i.Name,i.Name,i.Name,i.ValueType) #1=int, 2=float, 5=text
      
    #get candidate nodes and their attributes
    nodeNo, nodeX, nodeY = getCandidateNodesForConnectors(Visum,['5','6','7'])
    
    mazIds = Visum.Net.MainZones.GetMultiAttValues("No")
    mazXs = Visum.Net.MainZones.GetMultiAttValues("Xcoord")
    mazYs = Visum.Net.MainZones.GetMultiAttValues("Ycoord")
    
    print("create zones, add connectors")
    for i in range(len(mazIds)):
      zoneObj = Visum.Net.AddZone(mazIds[i][1])
      zoneObj.SetAttValue("Xcoord",mazXs[i][1])
      zoneObj.SetAttValue("Ycoord",mazYs[i][1])
      
      #Add connectors - note only distance used later for skimming
      nodeids = getClosestN(mazXs[i][1], mazYs[i][1], nodeNo, nodeX, nodeY, 4)
      for nid in nodeids:
        nodeObj = Visum.Net.Nodes.ItemByKey(nid)
        if not Visum.Net.Connectors.ExistsByKey(nodeObj, zoneObj):
          Visum.Net.AddConnector(zoneObj, nodeObj)

    print("copy UDAs and polygons")
    for i in Visum.Net.MainZones.Attributes.GetAll:
      if i.category=="User-defined attributes":
        attData = VisumPy.helpers.GetMulti(Visum.Net.MainZones, i.Name)
        VisumPy.helpers.SetMulti(Visum.Net.Zones, i.Name, attData) 
        
      #create zone polygon as well
      attData = VisumPy.helpers.GetMulti(Visum.Net.MainZones, "WKTSurface")
      VisumPy.helpers.SetMulti(Visum.Net.Zones, "WKTSurface", attData)
  
  #taps from stop areas to tazs           
  if zoneSystem=="tap":
    print("taps from stop areas to tazs")
    
    #move stoparea UDAs to taz UDAs
    print("move stoparea UDAs to taz UDAs")
    for i in Visum.Net.StopAreas.Attributes.GetAll:
      if i.category=="User-defined attributes":
        Visum.Net.Zones.AddUserDefinedAttribute(i.Name,i.Name,i.Name,i.ValueType) #1=int, 2=float, 5=text
    
    tapIds = Visum.Net.StopAreas.GetMultiAttValues("No")
    tapXs = Visum.Net.StopAreas.GetMultiAttValues("Xcoord")
    tapYs = Visum.Net.StopAreas.GetMultiAttValues("Ycoord")
    tapNodes = Visum.Net.StopAreas.GetMultiAttValues("NodeNo")
    
    print("create zones, add connectors, copy over UDAs, copy over polygons")
    for i in range(len(tapIds)):
      zoneObj = Visum.Net.AddZone(tapIds[i][1])
      zoneObj.SetAttValue("Xcoord",tapXs[i][1])
      zoneObj.SetAttValue("Ycoord",tapYs[i][1])
      
      #Add connector
      nodeObj = Visum.Net.Nodes.ItemByKey(tapNodes[i][1])
      if not Visum.Net.Connectors.ExistsByKey(nodeObj, zoneObj):
        conObj = Visum.Net.AddConnector(zoneObj, nodeObj)
        lenMiles = conObj.AttValue("Length")
        conObj.SetAttValue("T0_TSys(TransitWalk)",lenMiles * (60.0 / defaultWalkSpeed) * 60)
        
        conObj = Visum.Net.Connectors.DestItemByKey(nodeObj, zoneObj)
        lenMiles = conObj.AttValue("Length")
        conObj.SetAttValue("T0_TSys(TransitWalk)",lenMiles * (60.0 / defaultWalkSpeed) * 60)
      
      #set attributes
      tapObj = Visum.Net.StopAreas.ItemByKey(tapIds[i][1])
      for i in Visum.Net.StopAreas.Attributes.GetAll:
        if i.category=="User-defined attributes":
          zoneObj.SetAttValue(i.Name,tapObj.AttValue(i.Name))
          
  Visum.Graphic.StopDrawing=False
 
def assignStopAreasToAccessNodes(Visum):
  print("assign stop areas to access nodes")
  nodeNo, nodeX, nodeY = getCandidateNodesForConnectors(Visum,['3','4','5','6','7'])
  
  tapIds = Visum.Net.StopAreas.GetMultiAttValues("No")
  tapXs = Visum.Net.StopAreas.GetMultiAttValues("Xcoord")
  tapYs = Visum.Net.StopAreas.GetMultiAttValues("Ycoord")
    
  for i in range(len(tapIds)):
    nodeids = getClosestN(tapXs[i][1], tapYs[i][1], nodeNo, nodeX, nodeY, 1)
    Visum.Net.StopAreas.ItemByKey(tapIds[i][1]).SetAttValue("NodeNo",nodeids[0])

def createTapLines(Visum, fileName):
  print("create tap lines file")
  tapIds = Visum.Net.StopAreas.GetMultiAttValues("No")
  tapLines = Visum.Net.StopAreas.GetMultiAttValues("CONCATENATE:STOPPOINTS\CONCATENATE:LINEROUTES\LINENAME")  
  f = open(fileName,"wt")
  f.write("TAP,LINES\n")  
  for i in range(len(tapIds)):
    tap = tapIds[i][1]
    if tapLines[i][1] != "":
      lines = tapLines[i][1].replace(","," ")
    f.write("%s,%s\n" % (tap,lines))
  f.close()

def createMazToTap(Visum, mode, outFolder):
  
  print("create MAZ to TAP file")
  
  #settings
  SearchCrit = 1 #1=time,3=distance
  if mode == "Walk":
    MaxTime = 60.0 / 3.0 * 2.0 * 60.0 #3mph, 2 miles max, seconds
    BackToMiles = 60.0 / 3.0 * 60.0
  elif mode == "Bike":
    MaxTime = 60.0 / 10.0 * 5.0 * 60.0 #10mph, 5 miles max, seconds
    BackToMiles = 60.0 / 10.0 * 60.0
  tSys = mode
  
  #get all stop area nodes
  tapIds = Visum.Net.StopAreas.GetMultiAttValues("No")
  tapNodes = Visum.Net.StopAreas.GetMultiAttValues("NodeNo")
  
  #filter
  filter = Visum.Filters.ZoneFilter()
  filter.Init()
  filter.UseFilter = True
  filter.AddCondition("OP_NONE", False, "IsocTimePrT", "LessEqualVal", MaxTime)
  
  #create output file
  f = open(outFolder + "/tap2maz_" + mode + ".csv", 'wb')
  f.write("TAP,MAZ,DISTMILES\n")
  
  #loop though nodes and run isochrones
  Visum.Graphic.StopDrawing = True
  for i in range(len(tapNodes)):
    tap = tapIds[i][1]
    node = tapNodes[i][1]
    print("Get nearby MAZs by " + mode + " for TAP: " + str(tap) + " node: " + str(node))
    IsocNodes = Visum.CreateNetElements()
    Node = Visum.Net.Nodes.ItemByKey(node)
    IsocNodes.Add(Node)
    Visum.Analysis.Isochrones.ExecutePrT(IsocNodes, tSys, SearchCrit, MaxTime)
    IsocVal = VisumPy.helpers.GetMulti(Visum.Net.Zones, "IsocTimePrT", True)
    if len(IsocVal) > 1:
      DestID = VisumPy.helpers.GetMulti(Visum.Net.Zones, "SEQMAZ", True) #seq maz
      for j in range(len(DestID)):
        f.write("%i,%i,%.2f\n" % (tap,DestID[j],IsocVal[j] / BackToMiles))
    Visum.Analysis.Isochrones.Clear()
  
  #clean up    
  f.close()   
  Visum.Graphic.StopDrawing = False
  Visum.Filters.InitAll()

def createNearbyMazsFile(Visum, mode, outFolder):
  
  print("create nearby MAZs file")
  
  #max distance for nearby mazs
  if mode == "Walk":
    MaxDistMiles = 2 
  elif mode == "Bike":
    MaxDistMiles = 5
  DistMat = VisumPy.helpers.GetMatrix(Visum, 1) #numpy matrix
  Mazs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "SEQMAZ") #seq maz
  
  #create output file
  f = open(outFolder + "/maz2maz_" + mode + ".csv", 'wb')
  f.write("OMAZ,DMAZ,DISTMILES\n")
  for i in range(len(Mazs)):
    for j in range(len(Mazs)):
      if(DistMat[i][j]<MaxDistMiles):
        f.write("%i,%i,%.2f\n" % (Mazs[i],Mazs[j],DistMat[i][j]))
  f.close()

def tazsToTapsForDriveAccess(Visum, fileName, tapFileName):
  
  print("get all drive access taps by taz")
  
  tSysList = ['Bus'] #List of transit submodes
  maxDistByTsysList = [4] #List of max miles to each submode
  default_lot_capacity = 1
  
  #get TAZs and skims
  zoneIds = VisumPy.helpers.GetMulti(Visum.Net.Zones, "No")
  zoneXs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "Xcoord")
  zoneYs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "Ycoord")
  TimeMat = VisumPy.helpers.GetMatrix(Visum, 2) #SOV numpy matrix
  DistMat = VisumPy.helpers.GetMatrix(Visum, 3) #SOV
  TollMat = VisumPy.helpers.GetMatrix(Visum, 8) #SOVToll
  
  #get TAPs
  tapIds = VisumPy.helpers.GetMulti(Visum.Net.StopAreas,"No")
  tapTsys = VisumPy.helpers.GetMulti(Visum.Net.StopAreas,"CONCATENATE:STOPPOINTS\CONCATENATE:LINEROUTES\TSYSCODE")
  tapXs = VisumPy.helpers.GetMulti(Visum.Net.StopAreas,"Xcoord")
  tapYs = VisumPy.helpers.GetMulti(Visum.Net.StopAreas,"Ycoord")
  tapCanPnr = VisumPy.helpers.GetMulti(Visum.Net.StopAreas,"CANPNR")
  tapTaz = [-1]*len(tapIds)
  
  #assign TAP to TAZ
  print("assign stop areas to tazs")  
  for i in range(len(tapIds)):
    nodeids = getClosestN(tapXs[i], tapYs[i], zoneIds, zoneXs, zoneYs, 1)
    tapTaz[i] = nodeids[0]
  
  #write TAP file
  print("write tap data file")
  f = open(tapFileName, 'wb')
  f.write("tap,taz,lotid,capacity\n")
  for j in range(len(tapIds)):
    tap = tapIds[j]
    taz = tapTaz[j]
    f.write("%i,%i,%i,%i\n" % (tap,taz,tap,default_lot_capacity))
  f.close()
  
  #write all near TAPs that CANPNR
  print("write all near TAPs for drive access")  
  f = open(fileName, 'wb')
  f.write("FTAZ,MODE,PERIOD,TTAP,TMAZ,TTAZ,DTIME,DDIST,DTOLL,WDIST\n")
  for i in range(len(zoneIds)):
    for j in range(len(tapIds)):
      
      if tapCanPnr[j]==1: #CANPNR true or false
        
        for k in range(len(tSysList)):
        
          #get data
          ftaz = zoneIds[i]
          mode = tSysList[k]
          period = 0 #anytime of the day
          ttap = tapIds[j]
          tmaz = 0 #doesn't matter?
          ttaz = tapTaz[j]
          
          #get skim data
          tapsTazIndex = zoneIds.index(ttaz)
          dtime = TimeMat[i][tapsTazIndex]
          ddist = DistMat[i][tapsTazIndex]
          dtoll = TollMat[i][tapsTazIndex]
          wdist = 0 #doesn't matter
          
          #output if near; by modes served
          maxDist = maxDistByTsysList[k]
          modesServed = tapTsys[j].split(",")
          if(ddist < maxDist and mode in modesServed):
            dataItems = (ftaz,mode,period,ttap,tmaz,ttaz,dtime,ddist,dtoll,wdist)
            f.write("%i,%s,%i,%i,%i,%i,%.2f,%.2f,%.2f,%.2f\n" % dataItems)
          
  f.close()

def saveLinkSpeeds(Visum, fileName):
  
  speedField = "VCur_PrTSys(HOV3Toll)"
  print("save link assigned speed " + speedField + " for TTFs")
  
  #get TAZs and skims
  fn = VisumPy.helpers.GetMulti(Visum.Net.Links, "FROMNODENO")
  tn = VisumPy.helpers.GetMulti(Visum.Net.Links, "TONODENO")
  speed = VisumPy.helpers.GetMulti(Visum.Net.Links, speedField)
  f = open(fileName, 'wb')
  f.write("FROMNODE,TONODE,V0PRT\n")
  for i in range(len(fn)):
    f.write("%i,%i,%.2f\n" % (fn[i],tn[i],speed[i]))
  f.close()


def loadLinkSpeeds(Visum, fileName):
  
  speedField = "VCur_PrTSys(HOV3Toll)"
  print("load link assigned speed " + speedField + " into V0PrT for TTFs")
  
  #read speeds into network
  speeds = []
  i=0
  with open(fileName, 'rb') as csvfile:
    freader = csv.reader(csvfile, skipinitialspace=True)
    for row in freader:
      if i >0:
        speeds.append(float(row[2]))
      i=i+1
      
  VisumPy.helpers.SetMulti(Visum.Net.Links, "V0PrT", speeds)
  
def createAltFiles(Visum, outFolder):
  
  print("create alternatives files for CT-RAMP")  
  default_park_area = 4
  
  #get mazs
  real_mazs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "NO")
  mazs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "SEQMAZ") #seq maz
  
  #create output file
  f_pl_a = open(outFolder + "/ParkLocationAlts.csv", 'wb') 
  f_dc_a = open(outFolder + "/DestinationChoiceAlternatives.csv", 'wb') 
  f_soa_a = open(outFolder + "/SoaTazDistAlternatives.csv", 'wb') 
  f_psoa_a = open(outFolder + "/ParkLocationSampleAlts.csv", 'wb') 
  
  f_pl_a.write("a,mgra,parkarea\n") #a,maz,parkarea
  f_dc_a.write("a,mgra,dest\n") #a,maz,taz
  f_soa_a.write("a,dest\n") #a,taz
  f_psoa_a.write("a,mgra\n") #a,maz
  
  prev_taz = -1
  taz_alt_i = 0
  for i in range(len(mazs)):
    
    taz = int(str(int(real_mazs[i]))[0:-2]) #taz id inside maz id
    
    f_pl_a.write("%i,%i,%i\n" % (i+1,mazs[i],default_park_area))
    f_dc_a.write("%i,%i,%i\n" % (i+1,mazs[i],taz))
    if taz!=prev_taz:
      f_soa_a.write("%i,%i\n" % (taz_alt_i+1,taz))
      prev_taz = taz
      taz_alt_i = taz_alt_i + 1
    f_psoa_a.write("%i,%i\n" % (i+1,mazs[i]))
  
  f_pl_a.close()
  f_dc_a.close()
  f_soa_a.close()
  f_psoa_a.close()
  
def calculateDensityMeasures(Visum):
  
  print("create MAZ density measures")
    
  #create attributes if needed
  print("create density attributes if needed")
  udaNames = []
  for i in Visum.Net.Zones.Attributes.GetAll:
    if i.category=="User-defined attributes":
      udaNames.append(i.Name)
  if "DUDEN" not in udaNames:
    Visum.Net.Zones.AddUserDefinedAttribute("DUDEN","DUDEN","DUDEN",2,3) #1=int, 2=float, 5=text
  if "EMPDEN" not in udaNames:
    Visum.Net.Zones.AddUserDefinedAttribute("EMPDEN","EMPDEN","EMPDEN",2,3) #1=int, 2=float, 5=text
  if "TOTINT" not in udaNames:
    Visum.Net.Zones.AddUserDefinedAttribute("TOTINT","TOTINT","TOTINT",2,3) #1=int, 2=float, 5=text
  if "POPDEN" not in udaNames:
    Visum.Net.Zones.AddUserDefinedAttribute("POPDEN","POPDEN","POPDEN",2,3) #1=int, 2=float, 5=text
  if "RETDEN" not in udaNames:
    Visum.Net.Zones.AddUserDefinedAttribute("RETDEN","RETDEN","RETDEN",2,3) #1=int, 2=float, 5=text

  #get attributes
  mazIds = VisumPy.helpers.GetMulti(Visum.Net.Zones,"No")
  mazXs = VisumPy.helpers.GetMulti(Visum.Net.Zones,"Xcoord")
  mazYs = VisumPy.helpers.GetMulti(Visum.Net.Zones,"Ycoord")
  
  du = VisumPy.helpers.GetMulti(Visum.Net.Zones, "HH")
  pop = VisumPy.helpers.GetMulti(Visum.Net.Zones, "POP")
  emp = VisumPy.helpers.GetMulti(Visum.Net.Zones, "EMP_TOTAL")
  ret = VisumPy.helpers.GetMulti(Visum.Net.Zones, "EMP_RETAIL")
  sqmi = VisumPy.helpers.GetMulti(Visum.Net.Zones, "AreaMi2")
  
  duden = VisumPy.helpers.GetMulti(Visum.Net.Zones, "DUDEN")
  empden = VisumPy.helpers.GetMulti(Visum.Net.Zones, "EMPDEN")
  totint = VisumPy.helpers.GetMulti(Visum.Net.Zones, "TOTINT")
  popden = VisumPy.helpers.GetMulti(Visum.Net.Zones, "POPDEN")
  retden = VisumPy.helpers.GetMulti(Visum.Net.Zones, "RETDEN")
  av1 = VisumPy.helpers.GetMulti(Visum.Net.Zones, "AddVal1") #accumulate acres
  
  #node data for intersection calculation
  nodeIds = VisumPy.helpers.GetMulti(Visum.Net.Nodes,"No")
  nodeXs = VisumPy.helpers.GetMulti(Visum.Net.Nodes,"Xcoord")
  nodeYs = VisumPy.helpers.GetMulti(Visum.Net.Nodes,"Ycoord")
  nodeLegs = VisumPy.helpers.GetMulti(Visum.Net.Nodes,"NumLinks")
  
  #accumulate measures
  for i in range(len(mazIds)):
    
    #taz measures
    duden[i] = 0
    empden[i] = 0
    popden[i] = 0
    retden[i] = 0
    for j in range(len(mazIds)):
      dist = calcDist(mazXs[i],mazXs[j],mazYs[i],mazYs[j])
      if dist < (5280/2):
        duden[i] = duden[i] + du[j]
        empden[i] = empden[i] + emp[j]
        popden[i] = popden[i] + pop[j]
        retden[i] = retden[i] + ret[j]
        av1[i] = av1[i] + sqmi[j] * 640 #sqmi to acres
    
    #divide by acres
    if av1[i] > 0: 
      duden[i] = duden[i] / av1[i]
      empden[i] = empden[i] / av1[i]
      popden[i] = popden[i] / av1[i]
      retden[i] = retden[i] / av1[i]
    else:
      duden[i] = 0
      empden[i] = 0
      popden[i] = 0
      retden[i] = 0
    
    #total intersections
    totint[i] = 0
    for k in range(len(nodeIds)):
      if nodeLegs[k] > 3:
        dist = calcDist(mazXs[i],nodeXs[k],mazYs[i],nodeYs[k])
        if dist < (5280/2):
          totint[i] = totint[i] + 1

  #set attributes
  VisumPy.helpers.SetMulti(Visum.Net.Zones, "DUDEN", duden)
  VisumPy.helpers.SetMulti(Visum.Net.Zones, "EMPDEN", empden)
  VisumPy.helpers.SetMulti(Visum.Net.Zones, "TOTINT", totint)
  VisumPy.helpers.SetMulti(Visum.Net.Zones, "POPDEN", popden)
  VisumPy.helpers.SetMulti(Visum.Net.Zones, "RETDEN", retden)

  
def setSeqMaz(Visum):
  
  print("set SEQMAZ for CT-RAMP")
  
  zoneNum = VisumPy.helpers.GetMulti(Visum.Net.Zones,"NO")
  seqMaz = VisumPy.helpers.GetMulti(Visum.Net.Zones,"SEQMAZ")
  for i in range(len(zoneNum)):
    seqMaz[i] = i+1
  VisumPy.helpers.SetMulti(Visum.Net.Zones, "SEQMAZ", seqMaz)
  
def writeMazDataFile(Visum, fileName):
  
  print("write MAZ data file")
  
  fieldsToExport = ["SEQMAZ","NO","TAZ","DISTNAME","COUNTY","HH","POP","HHP",
    "EMP_CONSTR","EMP_WHOLE","EMP_RETAIL","EMP_SPORT","EMP_ACCFD","EMP_AGR",
    "EMP_MIN","EMP_UTIL","EMP_FOOD","EMP_WOOD","EMP_METAL","EMP_TRANS",
    "EMP_POSTAL","EMP_INFO","EMP_FINANC","EMP_REALES","EMP_PROF","EMP_MGMT",
    "EMP_ADMIN","EMP_EDUC","EMP_HEALTH","EMP_ARTS","EMP_OTHER","EMP_PUBADM",
    "EMP_TOTAL","ENROLLK_8","ENROLL9_12","ENROLLCOLL","ENROLLCOOT","ENROLLADSC",
    "universitySqFtClass","universitySqFtOffice","universitySqFtRec",
    "ECH_DIST","HCH_DIST","HOTELRMTOT","PARKAREA","HSTALLSOTH",
    "HSTALLSSAM","HPARKCOST","NUMFREEHRS","DSTALLSOTH","DSTALLSSAM",
    "DPARKCOST","MSTALLSOTH","MSTALLSSAM","MPARKCOST","WRK_EXT_PR","SCHDIST_NA",
    "SCHDIST","DUDEN","EMPDEN","TOTINT","POPDEN","RETDEN","TERMTIME","PARKACRES"]

  #create header
  header = ",".join(fieldsToExport)
  header = header.replace("SEQMAZ","MAZ") #required by CT-RAMP
  
  #create rows
  row = []
  for i in range(len(fieldsToExport)):
    uda = VisumPy.helpers.GetMulti(Visum.Net.Zones, fieldsToExport[i])
    if i==0:
      for j in range(len(uda)):
        row.append(str(uda[j]))
    else:
      for j in range(len(uda)):
        row[j] = row[j] + "," + str(uda[j])
  
  #create output file
  f = open(fileName, 'wb') 
  f.write(header + "\n")
  for i in range(len(row)):
    f.write(row[i] + "\n")
  f.close()

def setLinkCapacityTODFactors(Visum, tp):

  print("set time period link capacities on Links and Network")

  #factors to convert hourly link capacities to time period capacities
  tods =    ["ea","am","md","pm","ev"]
  factors = [4   ,1.5 ,8   ,2   ,8.5 ]
  capFac = factors[tods.index(tp)]
  
  vdf_mid_link_cap = VisumPy.helpers.GetMulti(Visum.Net.Links, "vdf_mid_link_cap")
  vdf_int_cap = VisumPy.helpers.GetMulti(Visum.Net.Links, "vdf_int_cap")
  
  #set factor
  attName = "TOD_FACTOR_" + tp
  if attName not in map(lambda x: x.Code,Visum.Net.Attributes.GetAll):
    Visum.Net.AddUserDefinedAttribute(attName,attName,attName,2)
  Visum.Net.SetAttValue(attName, capFac)
  
  #convert from hourly to time period
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_mid_link_cap", vdf_mid_link_cap * capFac)
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_int_cap", vdf_int_cap * capFac) 
  
def setLinkSpeedTODFactors(Visum, linkSpeedsFileName):

  print("set time period link speeds")

  print("read link speeds input file")
  speeds = []
  with open(linkSpeedsFileName, 'rb') as csvfile:
    freader = csv.reader(csvfile, skipinitialspace=True)
    for row in freader:
      speeds.append(row)
  speeds_col_names = speeds.pop(0)
  
  #create dictionary for tod speed lookup - PLANNO,SPEED,TOD = TODSPEED
  speeds_lookup = dict()
  for row in speeds:
    speeds_lookup[row[0] + "," + row[1] + "," + row[2]] = row[3]
  
  print("loop through links and set speed by TOD")
  tods = ["EA","AM","MD","PM","EV"]
  for tod in tods:
    fc = VisumPy.helpers.GetMulti(Visum.Net.Links, "PLANNO")
    ffspeed = VisumPy.helpers.GetMulti(Visum.Net.Links, "V0PRT")
    speed = VisumPy.helpers.GetMulti(Visum.Net.Links, tod+"_Speed")
    for i in range(len(fc)):
      speed[i] = float(speeds_lookup[str(int(fc[i])) + "," + str(int(ffspeed[i])) + "," + tod])
  VisumPy.helpers.SetMulti(Visum.Net.Links, tod+"_Speed", speed)
  
def createTapFareMatrix(Visum, faresFileName, fileName):
  
  print("create OD fare matrix")
  
  print("read fare input file")
  odfare = []
  with open(faresFileName, 'rb') as csvfile:
    freader = csv.reader(csvfile, skipinitialspace=True)
    for row in freader:
      odfare.append(row)
  odfare_col_names = odfare.pop(0)
  
  #create dictionary for fare lookup
  fare_lookup = dict()
  for row in odfare:
    fare_lookup[row[0] + "," + row[1]] = row[2]
  
  print("loop through TAP TAP ODs and set fare")
  fzs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "FareZone")
  mat = numpy.zeros((len(fzs),len(fzs)))  
  for i in range(len(fzs)):
    for j in range(len(fzs)):
      mat[i][j] = float(fare_lookup[fzs[i] + "," + fzs[j]])
  
  #write fare matrix
  omxFile = omx.openFile(fileName,'w')
  omxFile['fare'] = mat
  omxFile.close()

def updateFareSkim(Visum, inputFareOmxFile, inputMatName, updateFareOmxFile, updateMatName):

  print("update skimmed fare matrix with OD-based created earlier")

  omxFile = omx.openFile(inputFareOmxFile,'a')
  fare = numpy.array(omxFile[inputMatName])
  omxFile.close()
  
  omxUpdateFile = omx.openFile(updateFareOmxFile,'a')
  omxUpdateFile[updateMatName][:] = fare #[:] update items, not object 
  omxUpdateFile.close()
  
def reviseDuplicateSkims(Visum, omxFile1, omxFile2, omxFile3):

  print("NA duplicate OD pairs that have the same total time across skim sets")

  #parameters
  NA = 0
  skims = ["1","2","3","4","5","6","7","8","9","10"]
  
  omxFile1 = omx.openFile(omxFile1,'a')
  omxFile2 = omx.openFile(omxFile2,'a')
  omxFile3 = omx.openFile(omxFile3,'a')
  
  #if total time (IVT+OWT+TWT+WKT) is equal, then set skims to NA
  timeSet1 = numpy.array(omxFile1["1"]) + numpy.array(omxFile1["2"]) + numpy.array(omxFile1["3"]) + numpy.array(omxFile1["4"])
  timeSet2 = numpy.array(omxFile2["1"]) + numpy.array(omxFile2["2"]) + numpy.array(omxFile2["3"]) + numpy.array(omxFile2["4"])
  timeSet3 = numpy.array(omxFile3["1"]) + numpy.array(omxFile3["2"]) + numpy.array(omxFile3["3"]) + numpy.array(omxFile3["4"])
  
  #compare sets
  for skim in skims:
    omxFile2[skim][timeSet1 == timeSet2] = NA
    omxFile3[skim][timeSet1 == timeSet3] = NA
    omxFile3[skim][timeSet2 == timeSet3] = NA
  
  omxFile1.close()
  omxFile2.close()
  omxFile3.close()

def loadTripMatrices(Visum, outputsFolder, timeperiod, type, setid=-1):
  
  print("load " + type + " trip matrices for " + timeperiod + ", set " + str(setid))
  
  #two EV periods so build list to loop through later
  matTP = timeperiod.upper()
  if matTP=="EV":
    matTP=["EV1","EV2"]
  else:
    matTP=[matTP]
    
  #taz or tap
  if type=="taz":
    
    #create matrices
    tazIds = VisumPy.helpers.GetMulti(Visum.Net.Zones, "No")
    sov = numpy.zeros((len(tazIds),len(tazIds)))
    hov2 = numpy.zeros((len(tazIds),len(tazIds)))
    hov3 = numpy.zeros((len(tazIds),len(tazIds)))
    truck = numpy.zeros((len(tazIds),len(tazIds)))
    sovtoll = numpy.zeros((len(tazIds),len(tazIds)))
    hov2toll = numpy.zeros((len(tazIds),len(tazIds)))
    hov3toll = numpy.zeros((len(tazIds),len(tazIds)))
    
    #open matrices
    cvmTrips = omx.openFile(outputsFolder + "\\cvmTrips.omx",'r')
    externalTrips = omx.openFile(outputsFolder + "\\externalOD.omx",'r')
    ctrampTazTrips = omx.openFile(outputsFolder + "\\ctrampTazTrips.omx",'r')
    
    #add matrices together
    for aMatTP in matTP:
      cvm_car = numpy.array(cvmTrips["car_" + aMatTP])
      cvm_su = numpy.array(cvmTrips["su_" + aMatTP])
      cvm_mu = numpy.array(cvmTrips["mu_" + aMatTP])
  
      ext_hbw = numpy.array(externalTrips[aMatTP + "_hbw"])
      ext_nhbnw = numpy.array(externalTrips[aMatTP + "_nhbnw"])
      ext_hbo = numpy.array(externalTrips[aMatTP + "_hbo"])
      ext_hbcoll = numpy.array(externalTrips[aMatTP + "_hbcoll"])
      ext_hbr = numpy.array(externalTrips[aMatTP + "_hbr"])
      ext_hbs = numpy.array(externalTrips[aMatTP + "_hbs"])
      ext_hbsch = numpy.array(externalTrips[aMatTP + "_hbsch"])
      ext_nhbw = numpy.array(externalTrips[aMatTP + "_nhbw"])
      ext_truck = numpy.array(externalTrips[aMatTP + "_truck"])
  
      ct_sov = numpy.array(ctrampTazTrips["sov_" + aMatTP])
      ct_hov2 = numpy.array(ctrampTazTrips["hov2_" + aMatTP])
      ct_hov3 = numpy.array(ctrampTazTrips["hov3_" + aMatTP])
      ct_sovtoll = numpy.array(ctrampTazTrips["sovtoll_" + aMatTP])
      ct_hov2toll = numpy.array(ctrampTazTrips["hov2toll_" + aMatTP])
      ct_hov3toll = numpy.array(ctrampTazTrips["hov3toll_" + aMatTP])
      
      sov = sov + cvm_car + ext_hbw + ext_nhbnw + ext_hbo + ext_hbcoll + ext_hbr + ext_hbs + ext_hbsch + ext_nhbw + ct_sov
      hov2 = hov2 + ct_hov2
      hov3 = hov3 + ct_hov3
      sovtoll = sovtoll + ct_sovtoll
      hov2toll = hov2toll + ct_hov2toll
      hov3toll = hov3toll + ct_hov3toll
      truck = truck + cvm_su + cvm_mu + ext_truck
  
    #write matrices to VISUM
    matNums = VisumPy.helpers.GetMulti(Visum.Net.Matrices, "No")
    
    sovMatNum = 100
    if sovMatNum not in matNums:
      sovHandle = Visum.Net.AddMatrix(sovMatNum)
    sovHandle = Visum.Net.Matrices.ItemByKey(sovMatNum)
    sovHandle.SetAttValue("DSEGCODE","SOV")
    sovHandle.SetAttValue("NAME","SOV Demand")
    VisumPy.helpers.SetMatrix(Visum, sovMatNum, sov)
    
    hov2MatNum = 101
    if hov2MatNum not in matNums:
      hov2Handle = Visum.Net.AddMatrix(hov2MatNum)
    hov2Handle = Visum.Net.Matrices.ItemByKey(hov2MatNum)
    hov2Handle.SetAttValue("DSEGCODE","HOV2")
    hov2Handle.SetAttValue("NAME","HOV2 Demand")
    VisumPy.helpers.SetMatrix(Visum, hov2MatNum, hov2)
    
    hov3MatNum = 102
    if hov3MatNum not in matNums:
      hov3Handle = Visum.Net.AddMatrix(hov3MatNum)
    hov3Handle = Visum.Net.Matrices.ItemByKey(hov3MatNum)
    hov3Handle.SetAttValue("DSEGCODE","HOV3")
    hov3Handle.SetAttValue("NAME","HOV3 Demand")
    VisumPy.helpers.SetMatrix(Visum, hov3MatNum, hov3)
    
    truckMatNum = 103
    if truckMatNum not in matNums:
      truckHandle = Visum.Net.AddMatrix(truckMatNum)
    truckHandle = Visum.Net.Matrices.ItemByKey(truckMatNum)
    truckHandle.SetAttValue("DSEGCODE","Truck")
    truckHandle.SetAttValue("NAME","Truck Demand")
    VisumPy.helpers.SetMatrix(Visum, truckMatNum, truck)
    
    sovtollMatNum = 104
    if sovtollMatNum not in matNums:
      sovtollHandle = Visum.Net.AddMatrix(sovtollMatNum)
    sovtollHandle = Visum.Net.Matrices.ItemByKey(sovtollMatNum)
    sovtollHandle.SetAttValue("DSEGCODE","SOVToll")
    sovtollHandle.SetAttValue("NAME","SOVToll Demand")
    VisumPy.helpers.SetMatrix(Visum, sovtollMatNum, sovtoll)
    
    hov2tollMatNum = 105
    if hov2tollMatNum not in matNums:
      hov2tollHandle = Visum.Net.AddMatrix(hov2tollMatNum)
    hov2tollHandle = Visum.Net.Matrices.ItemByKey(hov2tollMatNum)
    hov2tollHandle.SetAttValue("DSEGCODE","HOV2Toll")
    hov2tollHandle.SetAttValue("NAME","HOV2Toll Demand")
    VisumPy.helpers.SetMatrix(Visum, hov2tollMatNum, hov2toll)
    
    hov3tollMatNum = 106
    if hov3tollMatNum not in matNums:
      hov3tollHandle = Visum.Net.AddMatrix(hov3tollMatNum)
    hov3tollHandle = Visum.Net.Matrices.ItemByKey(hov3tollMatNum)
    hov3tollHandle.SetAttValue("DSEGCODE","HOV3Toll")
    hov3tollHandle.SetAttValue("NAME","HOV3Toll Demand")
    VisumPy.helpers.SetMatrix(Visum, hov3tollMatNum, hov3toll)
    
    #close files
    cvmTrips.close()
    externalTrips.close()
    ctrampTazTrips.close()

  if type=="tap":
    
    #create matrices
    tapIds = VisumPy.helpers.GetMulti(Visum.Net.Zones,"No")
    transit = numpy.zeros((len(tapIds),len(tapIds)))
    
    #open matrices 
    ctrampTapTrips = omx.openFile(outputsFolder + "\\ctrampTapTrips.omx",'r')
  
    #add matrices together
    for aMatTP in matTP:
      ct_transit = numpy.array(ctrampTapTrips["set_" + setid + "_" + aMatTP])
      transit = transit + ct_transit
      
    #add 0.001 to ensure assignment runs
    transit[0][1] = transit[0][1] + 0.001
    
    #write matrices to VISUM
    matNums = VisumPy.helpers.GetMulti(Visum.Net.Matrices, "No")
    transitMatNum = 107
    if transitMatNum not in matNums:
      transitHandle = Visum.Net.AddMatrix(transitMatNum)
    transitHandle = Visum.Net.Matrices.ItemByKey(transitMatNum)
    transitHandle.SetAttValue("DSEGCODE","Transit")
    transitHandle.SetAttValue("NAME","Transit Demand")
    VisumPy.helpers.SetMatrix(Visum, transitMatNum, transit)
    
    #close files
    ctrampTapTrips.close()

def whichTimePeriod(deptTime, timePeriodStarts):
  return(len(timePeriodStarts[deptTime >= timePeriodStarts])-1)
  
def buildTripMatrices(Visum, tripFileName, jointTripFileName, expansionFactor, tapFileName, fileNameTaz, fileNameTap, fileNamePark):
  
  print("build CT-RAMP trip matrices")
  
  expansionFactor = 1 / expansionFactor 
  hov2occ = 2.0
  hov3occ = 3.33
  
  uniqTazs = VisumPy.helpers.GetMulti(Visum.Net.Zones, "NO")       #used by CT-RAMP
  tazs   = VisumPy.helpers.GetMulti(Visum.Net.MainZones, "TAZ")    #used by CT-RAMP
  tapIds = VisumPy.helpers.GetMulti(Visum.Net.StopAreas,"NO")      #used by CT-RAMP
  
  #keep track of pnr trips to TAPs
  tapParks = [0] * len(tapIds)
  
  timePeriods =      ["EV1","EA","AM","MD","PM","EV2"]
  timePeriodStarts = [0    ,1   ,7   ,10  ,26  ,30   ]
  timePeriodStarts = numpy.array(timePeriodStarts)
  
  #build taz lookup for quick access later
  tazIds = [-1]*(len(tazs)+1) 
  for i in range(len(tazs)):
    tazIds[i] = uniqTazs.index(tazs[i])-1 #assumes seq maz ids
  
  #create empty matrices
  sov = numpy.zeros((len(timePeriods),len(uniqTazs),len(uniqTazs)))
  hov2 = numpy.zeros((len(timePeriods),len(uniqTazs),len(uniqTazs)))
  hov3 = numpy.zeros((len(timePeriods),len(uniqTazs),len(uniqTazs)))
  sovtoll = numpy.zeros((len(timePeriods),len(uniqTazs),len(uniqTazs)))
  hov2toll = numpy.zeros((len(timePeriods),len(uniqTazs),len(uniqTazs)))
  hov3toll = numpy.zeros((len(timePeriods),len(uniqTazs),len(uniqTazs)))
  set1 = numpy.zeros((len(timePeriods),len(tapIds),len(tapIds)))
  set2 = numpy.zeros((len(timePeriods),len(tapIds),len(tapIds)))
  set3 = numpy.zeros((len(timePeriods),len(tapIds),len(tapIds)))
  
  print("read tap data file for tap to taz mapping for pnr trips")
  taptaz = []
  with open(tapFileName, 'rb') as csvfile:
    freader = csv.reader(csvfile, skipinitialspace=True)
    for row in freader:
      taptaz.append(row)
  taptaz_col_names = taptaz.pop(0)
  
  print("read individual trips")
  trips = []
  with open(tripFileName, 'rb') as csvfile:
    freader = csv.reader(csvfile, skipinitialspace=True)
    for row in freader:
      trips.append(row)
  trips_col_names = trips.pop(0)
    
  print("process individual trips")
  omazColNum = trips_col_names.index('orig_maz')
  dmazColNum = trips_col_names.index('dest_maz')
  pmazColNum = trips_col_names.index('parking_maz')
  otapColNum = trips_col_names.index('trip_board_tap')
  dtapColNum = trips_col_names.index('trip_alight_tap')
  modeColNum = trips_col_names.index('trip_mode')
  deptColNum = trips_col_names.index('stop_period')
  inbColNum = trips_col_names.index('inbound')
  setColNum = trips_col_names.index('set')
  dpnumColNum = trips_col_names.index('driver_pnum')
  epnumColNum = trips_col_names.index('dest_escortee_pnum')
  
  for i in range(len(trips)):
    if (i % 10000) == 0:
      print("process individual trip record " + str(i))
    
    mode = int(trips[i][modeColNum])
    
    if mode == 1: #sov
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][omazColNum])
      d = int(trips[i][dmazColNum])
      p = int(trips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      sov[tod][o,d] = sov[tod][o,d] + expansionFactor
      
    if mode == 2: #sov toll
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][omazColNum])
      d = int(trips[i][dmazColNum])
      p = int(trips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      sovtoll[tod][o,d] = sovtoll[tod][o,d] + expansionFactor
      
    elif mode == 3: #hov2
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][omazColNum])
      d = int(trips[i][dmazColNum])
      p = int(trips[i][pmazColNum])
      
      #switch destination zone to parking zone
      if p > 0: 
        d = p
      o = tazIds[o]
      d = tazIds[d]
      
      #escort trips
      dpnum = int(trips[i][dpnumColNum])
      epnum = int(trips[i][epnumColNum])
      if dpnum==0:
        tripsToAdd = expansionFactor / hov2occ
      elif dpnum!=epnum:
        tripsToAdd = 0
      elif dpnum==epnum:
        tripsToAdd = expansionFactor
        
      hov2[tod][o,d] = hov2[tod][o,d] + tripsToAdd
      
    elif mode == 5: #hov2toll
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][omazColNum])
      d = int(trips[i][dmazColNum])
      p = int(trips[i][pmazColNum])
      
      #switch destination zone to parking zone
      if p > 0: 
        d = p
      o = tazIds[o]
      d = tazIds[d]
      
      #escort trips
      dpnum = int(trips[i][dpnumColNum])
      epnum = int(trips[i][epnumColNum])
      if dpnum==0:
        tripsToAdd = expansionFactor / hov2occ
      elif dpnum!=epnum:
        tripsToAdd = 0
      elif dpnum==epnum:
        tripsToAdd = expansionFactor
        
      hov2toll[tod][o,d] = hov2toll[tod][o,d] + tripsToAdd
      
    elif mode == 6: #hov3
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][omazColNum])
      d = int(trips[i][dmazColNum])
      p = int(trips[i][pmazColNum])
      
      #switch destination zone to parking zone
      if p > 0:
        d = p
      o = tazIds[o]
      d = tazIds[d]
      
      #escort trips
      dpnum = int(trips[i][dpnumColNum])
      epnum = int(trips[i][epnumColNum])
      if dpnum==0:
        tripsToAdd = expansionFactor / hov3occ
      elif dpnum!=epnum:
        tripsToAdd = 0
      elif dpnum==epnum:
        tripsToAdd = expansionFactor
        
      hov3[tod][o,d] = hov3[tod][o,d] + tripsToAdd
    
    elif mode == 8: #hov3 toll
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][omazColNum])
      d = int(trips[i][dmazColNum])
      p = int(trips[i][pmazColNum])
      
      #switch destination zone to parking zone
      if p > 0:
        d = p
      o = tazIds[o]
      d = tazIds[d]
      
      #escort trips
      dpnum = int(trips[i][dpnumColNum])
      epnum = int(trips[i][epnumColNum])
      if dpnum==0:
        tripsToAdd = expansionFactor / hov3occ
      elif dpnum!=epnum:
        tripsToAdd = 0
      elif dpnum==epnum:
        tripsToAdd = expansionFactor
        
      hov3toll[tod][o,d] = hov3toll[tod][o,d] + tripsToAdd
      
    elif mode == 11: #walk
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][otapColNum])
      d = int(trips[i][dtapColNum])
      o = tapIds.index(o)
      d = tapIds.index(d)
      setid = int(trips[i][setColNum])
      if setid==0:
        set1[tod][o,d] = set1[tod][o,d] + expansionFactor
      if setid==1:
        set2[tod][o,d] = set2[tod][o,d] + expansionFactor
      if setid==2:
        set3[tod][o,d] = set3[tod][o,d] + expansionFactor
        
    elif mode == 12: #pnr
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][otapColNum])
      d = int(trips[i][dtapColNum])
      o = tapIds.index(o)
      d = tapIds.index(d)
      setid = int(trips[i][setColNum])
      if setid==0:
        set1[tod][o,d] = set1[tod][o,d] + expansionFactor
      if setid==1:
        set2[tod][o,d] = set2[tod][o,d] + expansionFactor
      if setid==2:
        set3[tod][o,d] = set3[tod][o,d] + expansionFactor
      
      #add drive trip to station
      otap = int(trips[i][otapColNum])
      dtap = int(trips[i][dtapColNum])
      inbound = int(trips[i][inbColNum])
      if inbound:
        o = int(taptaz[tapIds.index(dtap)][1]) #tap,taz columns
        d = int(trips[i][dmazColNum])
        o = tazIds[o]
        d = tazIds[d]
        sov[tod][o,d] = sov[tod][o,d] + expansionFactor
        
      else:
        d = int(taptaz[tapIds.index(otap)][1]) #tap,taz columns
        o = int(trips[i][omazColNum])
        o = tazIds[o]
        d = tazIds[d]
        sov[tod][o,d] = sov[tod][o,d] + expansionFactor
        
        #outbound trip parks at lot
        tapParks[tapIds.index(otap)] = tapParks[tapIds.index(otap)] + expansionFactor
      
    elif mode == 13: #knr
      dept = int(trips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(trips[i][otapColNum])
      d = int(trips[i][dtapColNum])
      o = tapIds.index(o)
      d = tapIds.index(d)
      setid = int(trips[i][setColNum])
      if setid==0:
        set1[tod][o,d] = set1[tod][o,d] + expansionFactor
      if setid==1:
        set2[tod][o,d] = set2[tod][o,d] + expansionFactor
      if setid==2:
        set3[tod][o,d] = set3[tod][o,d] + expansionFactor
        
      #add drive trip to station
      otap = int(trips[i][otapColNum])
      dtap = int(trips[i][dtapColNum])
      inbound = int(trips[i][inbColNum])
      if inbound:
        o = int(taptaz[tapIds.index(dtap)][1]) #tap,taz columns
        d = int(trips[i][dmazColNum])
        o = tazIds[o]
        d = tazIds[d]
        hov2[tod][o,d] = hov2[tod][o,d] + (expansionFactor / hov2occ)
      else:
        d = int(taptaz[tapIds.index(otap)][1]) #tap,taz columns
        o = int(trips[i][omazColNum])
        o = tazIds[o]
        d = tazIds[d]
        hov2[tod][o,d] = hov2[tod][o,d] + (expansionFactor / hov2occ)
  
  print("read joint trips")
  jtrips = []
  with open(jointTripFileName, 'rb') as csvfile:
    freader = csv.reader(csvfile, skipinitialspace=True)
    for row in freader:
      jtrips.append(row)
  jtrips_col_names = jtrips.pop(0)
  
  print("process joint trips")
  omazColNum = jtrips_col_names.index('orig_mgra')
  dmazColNum = jtrips_col_names.index('dest_mgra')
  pmazColNum = jtrips_col_names.index('parking_mgra')
  otapColNum = jtrips_col_names.index('trip_board_tap')
  dtapColNum = jtrips_col_names.index('trip_alight_tap')
  modeColNum = jtrips_col_names.index('trip_mode')
  deptColNum = jtrips_col_names.index('stop_period')
  inbColNum = jtrips_col_names.index('inbound')
  setColNum = jtrips_col_names.index('set')
  numPartNum = jtrips_col_names.index('num_participants')
  
  for i in range(len(jtrips)):
    if (i % 10000) == 0:
      print("process joint trip record " + str(i))
    
    mode = int(jtrips[i][modeColNum])
    
    if mode == 1: #sov
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][omazColNum])
      d = int(jtrips[i][dmazColNum])
      p = int(jtrips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      sov[tod][o,d] = sov[tod][o,d] + expansionFactor
    
    if mode == 2: #sov toll
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][omazColNum])
      d = int(jtrips[i][dmazColNum])
      p = int(jtrips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      sovtoll[tod][o,d] = sovtoll[tod][o,d] + expansionFactor
      
    elif mode == 3: #hov2
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][omazColNum])
      d = int(jtrips[i][dmazColNum])
      p = int(jtrips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      hov2[tod][o,d] = hov2[tod][o,d] + expansionFactor
    
    elif mode == 5: #hov2 toll
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][omazColNum])
      d = int(jtrips[i][dmazColNum])
      p = int(jtrips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      hov2toll[tod][o,d] = hov2toll[tod][o,d] + expansionFactor
      
    elif mode == 6: #hov3
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][omazColNum])
      d = int(jtrips[i][dmazColNum])
      p = int(jtrips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      hov3[tod][o,d] = hov3[tod][o,d] + expansionFactor
    
    elif mode == 8: #hov3 toll
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][omazColNum])
      d = int(jtrips[i][dmazColNum])
      p = int(jtrips[i][pmazColNum])
      if p > 0: #switch destination zone to parking zone
        d = p
      o = tazIds[o]
      d = tazIds[d]
      hov3toll[tod][o,d] = hov3toll[tod][o,d] + expansionFactor
      
    elif mode == 11: #walk
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][otapColNum])
      d = int(jtrips[i][dtapColNum])
      num_participants = int(jtrips[i][numPartNum])
      o = tapIds.index(o)
      d = tapIds.index(d)
      setid = int(jtrips[i][setColNum])
      if setid==0:
        set1[tod][o,d] = set1[tod][o,d] + expansionFactor * num_participants
      if setid==1:
        set2[tod][o,d] = set2[tod][o,d] + expansionFactor * num_participants
      if setid==2:
        set3[tod][o,d] = set3[tod][o,d] + expansionFactor * num_participants
        
    elif mode == 12: #pnr
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][otapColNum])
      d = int(jtrips[i][dtapColNum])
      num_participants = int(jtrips[i][numPartNum])
      o = tapIds.index(o)
      d = tapIds.index(d)
      setid = int(jtrips[i][setColNum])
      if setid==0:
        set1[tod][o,d] = set1[tod][o,d] + expansionFactor * num_participants
      if setid==1:
        set2[tod][o,d] = set2[tod][o,d] + expansionFactor * num_participants
      if setid==2:
        set3[tod][o,d] = set3[tod][o,d] + expansionFactor * num_participants
      
      #add drive trip to station
      otap = int(jtrips[i][otapColNum])
      dtap = int(jtrips[i][dtapColNum])
      inbound = int(jtrips[i][inbColNum])
      if inbound:
        o = int(taptaz[tapIds.index(dtap)][1]) #tap,taz columns
        d = int(jtrips[i][dmazColNum])
        o = tazIds[o]
        d = tazIds[d]
        if num_participants == 2:
          hov2[tod][o,d] = hov2[tod][o,d] + expansionFactor
        else:
          hov3[tod][o,d] = hov3[tod][o,d] + expansionFactor
        
      else:
        d = int(taptaz[tapIds.index(otap)][1]) #tap,taz columns
        o = int(jtrips[i][omazColNum])
        o = tazIds[o]
        d = tazIds[d]
        if num_participants == 2:
          hov2[tod][o,d] = hov2[tod][o,d] + expansionFactor
        else:
          hov3[tod][o,d] = hov3[tod][o,d] + expansionFactor
        
        #outbound trip parks at lot
        tapParks[tapIds.index(otap)] = tapParks[tapIds.index(otap)] + expansionFactor
        
    elif mode == 13: #knr
      dept = int(jtrips[i][deptColNum])
      tod = whichTimePeriod(dept, timePeriodStarts)
      o = int(jtrips[i][otapColNum])
      d = int(jtrips[i][dtapColNum])
      num_participants = int(jtrips[i][numPartNum])
      o = tapIds.index(o)
      d = tapIds.index(d)
      setid = int(jtrips[i][setColNum])
      if setid==0:
        set1[tod][o,d] = set1[tod][o,d] + expansionFactor * num_participants
      if setid==1:
        set2[tod][o,d] = set2[tod][o,d] + expansionFactor * num_participants
      if setid==2:
        set3[tod][o,d] = set3[tod][o,d] + expansionFactor * num_participants
      
      #add drive trip to station
      otap = int(jtrips[i][otapColNum])
      dtap = int(jtrips[i][dtapColNum])
      inbound = int(jtrips[i][inbColNum])
      if inbound:
        o = int(taptaz[tapIds.index(dtap)][1]) #tap,taz columns
        d = int(jtrips[i][dmazColNum])
        o = tazIds[o]
        d = tazIds[d]
        if num_participants == 2:
          hov2[tod][o,d] = hov2[tod][o,d] + expansionFactor
        else:
          hov3[tod][o,d] = hov3[tod][o,d] + expansionFactor
      else:
        d = int(taptaz[tapIds.index(otap)][1]) #tap,taz columns
        o = int(jtrips[i][omazColNum])
        o = tazIds[o]
        d = tazIds[d]
        if num_participants == 2:
          hov2[tod][o,d] = hov2[tod][o,d] + expansionFactor
        else:
          hov3[tod][o,d] = hov3[tod][o,d] + expansionFactor

  #open output files
  omxFileTaz = omx.openFile(fileNameTaz,'w')
  omxFileTap = omx.openFile(fileNameTap,'w')
  
  #write lookups
  omxFileTaz.createMapping("NO",uniqTazs)
  omxFileTap.createMapping("NO",tapIds)
  
  #write matrices
  for i in range(len(timePeriods)):
    
    tpLabel = timePeriods[i]
    
    omxFileTaz['sov_' + tpLabel] = sov[i]
    omxFileTaz['hov2_' + tpLabel] = hov2[i]
    omxFileTaz['hov3_' + tpLabel] = hov3[i]
    omxFileTaz['sovtoll_' + tpLabel] = sovtoll[i]
    omxFileTaz['hov2toll_' + tpLabel] = hov2toll[i]
    omxFileTaz['hov3toll_' + tpLabel] = hov3toll[i]
    omxFileTap['set_1_' + tpLabel] = set1[i]
    omxFileTap['set_2_' + tpLabel] = set2[i]
    omxFileTap['set_3_' + tpLabel] = set3[i]
    
    print('sov_' + tpLabel + ": " + str(round(sov[i].sum(),2)))
    print('hov2_' + tpLabel + ": " + str(round((hov2[i]).sum(),2)))
    print('hov3_' + tpLabel + ": " + str(round((hov3[i]).sum(),2)))
    print('sovtoll_' + tpLabel + ": " + str(round(sovtoll[i].sum(),2)))
    print('hov2toll_' + tpLabel + ": " + str(round((hov2toll[i]).sum(),2)))
    print('hov3toll_' + tpLabel + ": " + str(round((hov3toll[i]).sum(),2)))
    print('set_1_' + tpLabel + ": " + str(round(set1[i].sum(),2)))
    print('set_2_' + tpLabel + ": " + str(round(set2[i].sum(),2)))
    print('set_3_' + tpLabel + ": " + str(round(set3[i].sum(),2)))
    
  omxFileTaz.close()
  omxFileTap.close()
  
  #write tap parking file
  f = open(fileNamePark, 'wb')
  f.write("TAP,PNRPARKS\n")
  for i in range(len(tapIds)):
    tap = tapIds[i]
    parks = tapParks[i]
    f.write("%i,%i\n" % (tap,parks))
  f.close()

def prepVDFData(Visum, vdfLookupTableFileName):

  #through capacity per lane by fc
  thru_cap_per_lane = dict()
  thru_cap_per_lane["1"] = 1950
  thru_cap_per_lane["3"] = 1800
  thru_cap_per_lane["4"] = 1800
  thru_cap_per_lane["5"] = 1400
  thru_cap_per_lane["6"] = 1400
  thru_cap_per_lane["7"] = 1400
  thru_cap_per_lane["30"] = 1400
  
  freeway_cap_per_auxlane = 1200

  
  #turn capacity by fc
  turn_cap_per_lane = dict()
  turn_cap_per_lane["1"] = 250
  turn_cap_per_lane["3"] = 250
  turn_cap_per_lane["4"] = 150
  turn_cap_per_lane["5"] = 100
  turn_cap_per_lane["6"] = 100
  turn_cap_per_lane["7"] = 100
  turn_cap_per_lane["30"] = 100
  
  int_app_cap_per_lane = 1800
  
  #intersection vdf lookup table
  #PLANNO,VALUE,1,3,4,5,6,7,30
  #1,gc4leg,0.35,0.39,0.5,0.56,0.56,0.63,0.47
  vdf_lookup_table = VisumPy.csvHelpers.readCSV(vdfLookupTableFileName)
  vdf_lookup = dict()
  for i in range(1,len(vdf_lookup_table)):
    for j in range(2,len(vdf_lookup_table[0])):
      key = vdf_lookup_table[i][0] + ";" + vdf_lookup_table[i][1] + ";" + vdf_lookup_table[0][j]
      vdf_lookup[key] = float(vdf_lookup_table[i][j])

  print("get link and node data for vdf calculation")
  
  fn = VisumPy.helpers.GetMulti(Visum.Net.Links, "FROMNODENO")
  tn = VisumPy.helpers.GetMulti(Visum.Net.Links, "TONODENO")
  planNo = VisumPy.helpers.GetMulti(Visum.Net.Links, "PLANNO")
  progression_factor = VisumPy.helpers.GetMulti(Visum.Net.Links, "PROGRESSION_FACTOR")
  
  lanes = VisumPy.helpers.GetMulti(Visum.Net.Links, "NUMLANES")
  al = numpy.nan_to_num(numpy.array(VisumPy.helpers.GetMulti(Visum.Net.Links, "AUX_LANES"), dtype=float))
  m = VisumPy.helpers.GetMulti(Visum.Net.Links, "MEDIAN")
  
  toMainNo = map(lambda x: x != 0 , VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNodeOrientation"))
  
  mid_link_cap_adj = VisumPy.helpers.GetMulti(Visum.Net.Links, "MID_LINK_CAP_ADJ") #default to zero
  
  #regular node
  rn_numlegs = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNode\NumLegs")
  rn_cType = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNode\ControlType")
  rn_tnOrient = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNodeOrientation")
  rn_tnMajFlw1 = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNode\MajorFlowOri1")
  rn_tnMajFlw2 = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNode\MajorFlowOri2")
  
  rn_tnode_fcs = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNode\Concatenate:InLinks\PlanNo")
  rn_tnode_orient = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNode\Concatenate:InLinks\ToNodeOrientation")
  rn_tnode_fnorient = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutTurns\ToLink\FromNodeOrientation")
  rn_tnode_turnorient = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutTurns\Orientation")
  rn_tnode_laneturn_orients = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutTurns\Concatenate:LaneTurns\ToOrientation")
  rn_tnode_laneturn_laneno = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutTurns\Concatenate:LaneTurns\FromLaneNo")
  
  #main node
  mn_numlegs = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNode\NumLegs")
  mn_cType = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNode\ControlType")
  mn_tnOrient = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNodeOrientation") #Not main node since these don't always make sense
  mn_tnMajFlw1 = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNode\MajorFlowOri1")
  mn_tnMajFlw2 = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNode\MajorFlowOri2")
  
  mn_tnode_fcs = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNode\Concatenate:InLinks\PlanNo")
  mn_tnode_orient = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToMainNode\Concatenate:InLinks\ToNodeOrientation") #Not main node since these don't always make sense
  mn_tnode_fnorient = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutMainTurns\ToLink\FromMainNodeOrientation")
  mn_tnode_turnorient = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutMainTurns\Orientation")
  mn_tnode_laneturn_orients = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutMainTurns\Concatenate:LaneTurns\ToOrientation")
  mn_tnode_laneturn_laneno = VisumPy.helpers.GetMulti(Visum.Net.Links, "Concatenate:OutMainTurns\Concatenate:LaneTurns\FromLaneNo")
 
  #regular or main node temp fields
  numlegs = [0]*len(planNo)
  cType = [0]*len(planNo)
  tnOrient = [0]*len(planNo)
  tnMajFlw1  = [0]*len(planNo)
  tnMajFlw2 = [0]*len(planNo)
  tnode_fcs = [0]*len(planNo)
  tnode_orient = [0]*len(planNo)
  tnode_fnorient = [0]*len(planNo)
  tnode_turnorient = [0]*len(planNo)
  tnode_laneturn_orients = [0]*len(planNo)
  tnode_laneturn_laneno = [0]*len(planNo)

  #calculated fields
  int_fc = [0]*len(planNo) #intersecting facility type
  rl = [0]*len(planNo) #out exclusive right lanes
  tl = [0]*len(planNo) #out shared or exclusive thru lanes
  ll = [0]*len(planNo) #out exclusive left lanes
  mid_link_cap = [0]*len(planNo) #mid link capacity
  unc_sig_delay = [0]*len(planNo) #uncongested signal delay
  int_cap = [0]*len(planNo) #intersection capacity
  
  #additional output fields
  if "vdf_int_fc" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_int_fc","vdf_int_fc","vdf_int_fc",2)
  if "vdf_rl" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_rl","vdf_rl","vdf_rl",2)
  if "vdf_tl" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_tl","vdf_tl","vdf_tl",2)
  if "vdf_ll" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_ll","vdf_ll","vdf_ll",2)
  if "vdf_mid_link_cap" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_mid_link_cap","vdf_mid_link_cap","vdf_mid_link_cap",2)
  if "vdf_unc_sig_delay" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_unc_sig_delay","vdf_unc_sig_delay","vdf_unc_sig_delay",2)
  if "vdf_int_cap" not in map(lambda x: x.Code,Visum.Net.Links.Attributes.GetAll):
    Visum.Net.Links.AddUserDefinedAttribute("vdf_int_cap","vdf_int_cap","vdf_int_cap",2)
  
  print("loop through links")
  
  try:
    
    for i in range(len(planNo)):
      
      if toMainNo[i]:  #main node
        
        numlegs[i] = mn_numlegs[i]
        cType[i] = mn_cType[i]
        tnOrient[i] = mn_tnOrient[i]
        tnMajFlw1[i] = mn_tnMajFlw1[i]
        tnMajFlw2[i] = mn_tnMajFlw2[i]
        
        tnode_fcs[i] = mn_tnode_fcs[i]
        tnode_orient[i] = mn_tnode_orient[i]
        tnode_fnorient[i] = mn_tnode_fnorient[i]
        tnode_turnorient[i] = mn_tnode_turnorient[i]
        tnode_laneturn_orients[i] = mn_tnode_laneturn_orients[i]
        tnode_laneturn_laneno[i] = mn_tnode_laneturn_laneno[i]
      
      else: #regular node
      
        numlegs[i] = rn_numlegs[i]
        cType[i] = rn_cType[i]
        tnOrient[i] = rn_tnOrient[i]
        tnMajFlw1[i] = rn_tnMajFlw1[i]
        tnMajFlw2[i] = rn_tnMajFlw2[i]
        
        tnode_fcs[i] = rn_tnode_fcs[i]
        tnode_orient[i] = rn_tnode_orient[i]
        tnode_fnorient[i] = rn_tnode_fnorient[i]
        tnode_turnorient[i] = rn_tnode_turnorient[i]
        tnode_laneturn_orients[i] = rn_tnode_laneturn_orients[i]
        tnode_laneturn_laneno[i] = rn_tnode_laneturn_laneno[i]

      #skip if link closed
      if tnOrient[i] == 0 or planNo[i] == 998:
        continue
        
      mlc = thru_cap_per_lane[str(int(planNo[i]))]
      if planNo[i] == 1: #interstate
        mid_link_cap[i] = lanes[i] * mlc + al[i] * freeway_cap_per_auxlane
      else:
        mid_link_cap[i] = lanes[i] * mlc - 300 - 200 * (m[i]==0)

      if numlegs[i] >= 3:
        
        #get to node incoming link orientations and facility types
        int_fcs = tnode_fcs[i].split(",")
        int_orients = tnode_orient[i].split(",")

        #skip if not a real intersection
        while '998' in int_fcs:
          index = int_fcs.index('998')
          int_fcs.pop(index)
          int_orients.pop(index)
          if len(int_fcs) < 3:
            continue
            
        #if all same or just one different
        if len(set(int_fcs)) == 1:
          int_fc[i] = list(int_fcs)[0]
          
        elif len(set(int_fcs)) == 2:
          int_fcs.remove(str(int(planNo[i])))
          int_fc[i] = list(int_fcs)[0]
          
        else:
          #buid lookup and calculate based on compass orientation
          tonode_lookup = dict( zip(int_orients, int_fcs) )
          
          #code intersecting fc
          if tnOrient[i] in [15,1,3,11,9,7]: #NW,N,NE,SW,S,SE
            west, east = 999,999
            if tonode_lookup.has_key('ORIENTATIONWEST'):
              west = int(tonode_lookup['ORIENTATIONWEST'])
            if tonode_lookup.has_key('ORIENTATIONEAST'):
              east = int(tonode_lookup['ORIENTATIONEAST'])
            int_fc[i] = min(west, east) #take higher order fc

          if tnOrient[i] in [5,13]: #E,W
            north, south = 999,999
            if tonode_lookup.has_key('ORIENTATIONNORTH'):
              north = int(tonode_lookup['ORIENTATIONNORTH'])
            if tonode_lookup.has_key('ORIENTATIONNORTHEAST'):
              north = int(tonode_lookup['ORIENTATIONNORTHEAST'])
            if tonode_lookup.has_key('ORIENTATIONNORTHWEST'):
              north = int(tonode_lookup['ORIENTATIONNORTHWEST'])
            if tonode_lookup.has_key('ORIENTATIONSOUTH'):
              south = int(tonode_lookup['ORIENTATIONSOUTH'])
            if tonode_lookup.has_key('ORIENTATIONSOUTHEAST'):
              south = int(tonode_lookup['ORIENTATIONSOUTHEAST'])
            if tonode_lookup.has_key('ORIENTATIONSOUTHWEST'):
              south = int(tonode_lookup['ORIENTATIONSOUTHWEST'])
            int_fc[i] = min(north, south) #take higher order fc

        #determine cycle length and gcratio
        if cType[i] == 0: #0=unknown
            continue
        if cType[i] == 1: #0=unknown,1=uncontrolled,2=twowaystop,3=signal,4=allwaystop,5=roundabout,6=twowayyield
            continue
        elif cType[i] == 2:
          if tnOrient[i] not in [tnMajFlw1[i], tnMajFlw2[i]]: #not major flow link, i.e. stop controlled
            gc_type = "stop" 
          else:
            continue
        elif cType[i] == 3:
          gc_type = "gc3leg" if numlegs[i] == 3 else "gc4leg"
        elif cType[i] == 4:
          gc_type = "stop"
        elif cType[i] == 5:
          gc_type = "roundabout"
        cyclelength = vdf_lookup[str(int(planNo[i])) + ";cyclelength;" + str(int_fc[i])]
        gc = vdf_lookup[str(int(planNo[i])) + ";" + gc_type + ";" + str(int_fc[i])]

        unc_sig_delay[i] = progression_factor[i] * (cyclelength / 2) * (1 - gc)**2
        unc_sig_delay[i] = unc_sig_delay[i] * 100 #scale up since AddVal2 only supports ints
                        
        #right lanes, thru lanes, left lanes at intersection
        int_fnorient = tnode_fnorient[i].split(",")
        int_turno = tnode_turnorient[i].split(",")
        int_lturns_orient = tnode_laneturn_orients[i].split(",")
        int_lturns_laneno = tnode_laneturn_laneno[i].split(",")
        
        #assign L,T,R to lane turns
        int_lturns_ltr = [0]*len(int_lturns_laneno) #lane turns by L,T,R
        for j in range(len(int_turno)):
          nchar = len(int_turno[j])
          if int_turno[j][(nchar-1):nchar] == "R": #right
            for k in range(len(int_lturns_orient)):
              if int_lturns_orient[k] == int_fnorient[j]:
                int_lturns_ltr[k] = "R"
          if int_turno[j][(nchar-1):nchar] == "T": #thru
            for k in range(len(int_lturns_orient)):
              if int_lturns_orient[k] == int_fnorient[j]:
                int_lturns_ltr[k] = "T"
          if int_turno[j][(nchar-1):nchar] == "L": #left
            for k in range(len(int_lturns_orient)):
              if int_lturns_orient[k] == int_fnorient[j]:
                int_lturns_ltr[k] = "L"
        
        #count up lanes by movement
        laneno_ltr = dict()
        for j in range(len(int_lturns_laneno)):
          if laneno_ltr.has_key(int_lturns_laneno[j]):
            laneno_ltr[int_lturns_laneno[j]] = laneno_ltr[int_lturns_laneno[j]] + "," + str(int_lturns_ltr[j])
          else:
            laneno_ltr[int_lturns_laneno[j]] = str(int_lturns_ltr[j])
        for j in laneno_ltr.keys():
          if "R" in laneno_ltr[j] and "T" not in laneno_ltr[j] and "L" not in laneno_ltr[j]: #exclusive
            rl[i] = rl[i] + 1
          if "T" in laneno_ltr[j]: #shared ok
            tl[i] = tl[i] + 1
          if "R" not in laneno_ltr[j] and "T" not in laneno_ltr[j] and "L" in laneno_ltr[j]: #exclusive
            ll[i] = ll[i] + 1

        tlf = turn_cap_per_lane[str(int(planNo[i]))]
        int_cap[i] = gc * (tl[i] * int_app_cap_per_lane + (rl[i] + ll[i]) * tlf)
                
  except Exception as e:
      traceback.print_exc()
      print("link fn=" + str(int(fn[i])) + " tn=" + str(int(tn[i])))
  
  #set results  
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_int_fc", int_fc) #intersecting functional class
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_rl", rl) #exclusive right lanes
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_tl", tl) #thru lanes
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_ll", ll) #exclusive left lanes
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_mid_link_cap", mid_link_cap) #mid-link capacity
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_unc_sig_delay", unc_sig_delay) #uncongested signal delay
  VisumPy.helpers.SetMulti(Visum.Net.Links, "vdf_int_cap", int_cap) #intersection capacity
  
  print("set results in version file")
  
  #set TYPENO = PLANNO for VDF parameter lookup in procedures
  #para_a is midlink a, para_b is midlink b, para_a2 is intersection a, para_b2 is intersection b
  planNo = VisumPy.helpers.GetMulti(Visum.Net.Links, "PLANNO")
  VisumPy.helpers.SetMulti(Visum.Net.Links, "TYPENO", planNo)
 
############################################################

if __name__== "__main__":
  
  #get command line arguments
  runmode = sys.argv[1].lower()
    
  print("start " + runmode + " run: " + time.ctime())
  if runmode == 'maz_initial':
    try:
      Visum = startVisum()
      loadVersion(Visum, "inputs/SOABM.ver")
      assignStopAreasToAccessNodes(Visum)
      switchZoneSystem(Visum, "maz")
      calculateDensityMeasures(Visum)
      setSeqMaz(Visum)
      saveVersion(Visum, "outputs/networks/maz_skim_initial.ver")
      createAltFiles(Visum, "outputs/other")
      writeMazDataFile(Visum, "inputs/maz_data_export.csv")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)
  
  if runmode == 'maz_skim':
    try:
      Visum = startVisum()
      for mode in ["Walk","Bike"]:
        loadVersion(Visum, "outputs/networks/maz_skim_initial.ver")
        createMazToTap(Visum, mode, "outputs/skims")
        loadProcedure(Visum, "config/visum/maz_skim_" + mode + ".xml")
        createNearbyMazsFile(Visum, mode, "outputs/skims")
        saveVersion(Visum, "outputs/networks/maz_skim_" + mode + ".ver")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)
    
  if runmode == 'taz_initial':
    try:
      Visum = startVisum()
      loadVersion(Visum, "inputs/SOABM.ver")
      #codeTAZConnectors(Visum) #TAZ connectors input in master version file
      saveVersion(Visum, "outputs/networks/taz_skim_initial.ver")
      closeVisum(Visum)
      sys.exit(0)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)
      
  if runmode == 'taz_skim_speed': #tomtom speeds
    try:
      Visum = startVisum()
      loadVersion(Visum, "outputs/networks/taz_skim_initial.ver")
      prepVDFData(Visum, "inputs/vdf_lookup_table.csv")
      saveVersion(Visum, "outputs/networks/taz_skim_initial.ver")
      for tp in ['ea','am','md','pm','ev']:
        loadVersion(Visum, "outputs/networks/taz_skim_initial.ver")
        setLinkCapacityTODFactors(Visum, tp)
        setLinkSpeedTODFactors(Visum, "inputs/linkSpeeds.csv")
        loadProcedure(Visum, "config/visum/taz_skim_" + tp + "_speed.xml")
        saveVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
      loadVersion(Visum, "outputs/networks/taz_skim_am_speed.ver")
      tazsToTapsForDriveAccess(Visum, "outputs/skims/drive_taz_tap.csv", "outputs/skims/tap_data.csv")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)

  if runmode == 'taz_skim': #using modeled speeds and assign
    try:
      Visum = startVisum()
      for tp in ['ea','am','md','pm','ev']:
        loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
        loadProcedure(Visum, "config/visum/taz_skim_" + tp + ".xml")
        saveVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
      loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
      tazsToTapsForDriveAccess(Visum, "outputs/skims/drive_taz_tap.csv", "outputs/skims/tap_data.csv")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)

  if runmode == 'generate_html_inputs': #BMP 10/31/17, write out link volumes on count locations,links and total vmt
    try:
      Visum = startVisum()
      loadVersion(Visum, "inputs/SOABM.ver")
      dst_list = VisumPy.helpers.GetMulti(Visum.Net.Links, "Length")
      link_planno = VisumPy.helpers.GetMulti(Visum.Net.Links, "PLANNO")
      linkID = VisumPy.helpers.GetMulti(Visum.Net.Links, "No")
      fromNode = VisumPy.helpers.GetMulti(Visum.Net.Links, "FromNodeNo")
      toNode = VisumPy.helpers.GetMulti(Visum.Net.Links, "ToNodeNo")
      countLocs = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "No")
      planno = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "Link\PLANNO")
      am_count = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "AM_COUNT")
      md_count = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "MD_COUNT")
      pm_count = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "PM_COUNT")
      day_count = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "DAY_COUNT_FINAL")
      loadVersion(Visum, "outputs/networks/tap_skim_am_speed_set1.ver")
      lineRoutes = VisumPy.helpers.GetMulti(Visum.Net.LineRoutes, "LineName")
      f = open("outputs/other/ABM_Summaries/countLocCounts.csv", 'wb')
      f.write("id,FACTYPE,am_vol,md_vol,pm_vol,day_vol\n")
      for i in range(len(countLocs)):
          f.write("%i,%i,%.3f,%.3f,%.3f,%.3f\n" % (countLocs[i],planno[i],am_count[i],md_count[i],pm_count[i],day_count[i]))
      f.close()
      vol_list = [[0]*len(countLocs) for i in range(6)]
      all_vol_list = [[0]*len(dst_list) for i in range(6)]
      auto_vol_list = [[0]*len(dst_list) for i in range(6)]
      truck_vol_list = [[0]*len(dst_list) for i in range(6)]
      vmt_list = [[0]*5 for i in range(6)]
      numRoutes = len(lineRoutes) + 1
      #print("Number of Routes: " + str(numRoutes))
      lineUTrips = [[0]*numRoutes for i in range(6)]
      tod_cnt = 0
      for tp in ['ea','am','md','pm','ev']:
        loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
        vol_list[tod_cnt] = VisumPy.helpers.GetMulti(Visum.Net.CountLocations, "Link\VolVehPrT(AP)")
        all_vol_list[tod_cnt] = VisumPy.helpers.GetMulti(Visum.Net.Links, "VolVehPrT(AP)")
        sov_list = VisumPy.helpers.GetMulti(Visum.Net.Links, "VolVeh_TSys(SOV,AP)")
        hv2_list = VisumPy.helpers.GetMulti(Visum.Net.Links, "VolVeh_TSys(HOV2,AP)")
        hv3_list = VisumPy.helpers.GetMulti(Visum.Net.Links, "VolVeh_TSys(HOV3,AP)")
        trk_list = VisumPy.helpers.GetMulti(Visum.Net.Links, "VolVeh_TSys(Truck,AP)")
        loadVersion(Visum, "outputs/networks/tap_skim_" + tp + "_speed_set1.ver")
        line_utrips = VisumPy.helpers.GetMulti(Visum.Net.LineRoutes, "PTripsUnlinked(AP)")
        for rt in range(numRoutes-1):
          lineUTrips[tod_cnt][rt] = line_utrips[rt]
        lineUTrips[tod_cnt][numRoutes-1] = sum(line_utrips)
        for i in range(len(countLocs)):
          vol_list[5][i] = vol_list[5][i] + vol_list[tod_cnt][i]
        for i in range(len(linkID)):
          all_vol_list[5][i] = all_vol_list[5][i] + all_vol_list[tod_cnt][i]
          auto_vol_list[tod_cnt][i] = sov_list[i] + hv2_list[i] + hv3_list[i]
          auto_vol_list[5][i] = auto_vol_list[5][i] + auto_vol_list[tod_cnt][i]
          truck_vol_list[tod_cnt][i] = trk_list[i]
          truck_vol_list[5][i] = truck_vol_list[5][i] + truck_vol_list[tod_cnt][i]
        vmt_list[tod_cnt][0] = numpy.dot(dst_list, sov_list)
        vmt_list[tod_cnt][1] = numpy.dot(dst_list, hv2_list)
        vmt_list[tod_cnt][2] = numpy.dot(dst_list, hv3_list)
        vmt_list[tod_cnt][3] = numpy.dot(dst_list, trk_list)
        vmt_list[tod_cnt][4] = vmt_list[tod_cnt][0] + vmt_list[tod_cnt][1] + vmt_list[tod_cnt][2] + vmt_list[tod_cnt][3]
        vmt_list[5][0] = vmt_list[5][0] + vmt_list[tod_cnt][0]
        vmt_list[5][1] = vmt_list[5][1] + vmt_list[tod_cnt][1]
        vmt_list[5][2] = vmt_list[5][2] + vmt_list[tod_cnt][2]
        vmt_list[5][3] = vmt_list[5][3] + vmt_list[tod_cnt][3]
        vmt_list[5][4] = vmt_list[5][4] + vmt_list[tod_cnt][4]
        for rt in range(numRoutes):
          lineUTrips[5][rt] = lineUTrips[5][rt] + lineUTrips[tod_cnt][rt]	  
        tod_cnt = tod_cnt + 1
      f = open("outputs/other/ABM_Summaries/countLocVolumes.csv", 'wb')
      f.write("id,FACTYPE,am_vol,md_vol,pm_vol,day_vol\n")
      for i in range(len(countLocs)):
          f.write("%i,%i,%.3f,%.3f,%.3f,%.3f\n" % (countLocs[i],planno[i],vol_list[1][i],vol_list[2][i],vol_list[3][i],vol_list[5][i]))
      f.close()
      f = open("outputs/other/ABM_Summaries/allLinkSummary.csv", 'wb')
      f.write("id,From_Node,To_Node,FACTYPE,am_vol,md_vol,pm_vol,day_vol\n")
      for i in range(len(linkID)):
          f.write("%i,%i,%i,%i,%.3f,%.3f,%.3f,%.3f\n" % (linkID[i],fromNode[i],toNode[i],link_planno[i],all_vol_list[1][i],all_vol_list[2][i],all_vol_list[3][i],all_vol_list[5][i]))
      f.close()
      f = open("outputs/other/ABM_Summaries/vmtSummary.csv", 'wb')
      f.write("TOD,SOV,HOV2,HOV3,Truck,Total\n")
      tod_cnt = 0
      for tp in ['EA','AM','MD','PM','EV','Daily']:
          f.write("%s,%.3f,%.3f,%.3f,%.3f,%.3f\n" % (tp,vmt_list[tod_cnt][0],vmt_list[tod_cnt][1],vmt_list[tod_cnt][2],vmt_list[tod_cnt][3],vmt_list[tod_cnt][4]))
          tod_cnt = tod_cnt + 1
      f.close()
      f = open("outputs/other/ABM_Summaries/transitBoardingSummary.csv", 'wb')
      f.write("TOD,")
      for rt in range(numRoutes-1):
         f.write("%s," % (lineRoutes[rt]))
      f.write("Total\n")
      for tp in ['Daily']:
          f.write("%s," % (tp)) 
          for rt in range(numRoutes-1):
             f.write("%.3f," % (lineUTrips[5][rt]))
          f.write("%.3f\n" % (lineUTrips[5][numRoutes-1]))
      f.close()
      # write out final volumes to each period version files
      for tp in ['ea','am','md','pm','ev']:
        loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
        mode_count = 0
        for mode_var in ['AUTO','TRUCK','TOTAL']:
          if mode_var=="AUTO":
            set_list = auto_vol_list
          elif mode_var=="TRUCK":
            set_list = truck_vol_list
          else:
            set_list = all_vol_list
          tod_cnt = 0
          for tod_var in ['EA','AM','MD','PM','EV','DAILY']:
            field_name = tod_var + "_Vol_" + mode_var
            Visum.Net.Links.AddUserDefinedAttribute(field_name,field_name,field_name,2,3)
            VisumPy.helpers.SetMulti(Visum.Net.Links, field_name, set_list[tod_cnt])
            tod_cnt = tod_cnt + 1
          mode_count = mode_count + 1	
          saveVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")		
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)

  if runmode == 'tap_initial':
    try:
      Visum = startVisum()
      loadVersion(Visum, "inputs/SOABM.ver")
      assignStopAreasToAccessNodes(Visum)
      switchZoneSystem(Visum, "tap")
      saveVersion(Visum, "outputs/networks/tap_skim_initial.ver")
      createTapLines(Visum, "outputs/skims/tapLines.csv")
      createTapFareMatrix(Visum, "inputs/fares.csv", "outputs/skims/fare.omx")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)

  if runmode == 'tap_skim_speed':
    try:
    Visum = startVisum()
      for tp in ['ea','am','md','pm','ev']:
        loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
        saveLinkSpeeds(Visum, "outputs/networks/taz_skim_" + tp + "_speed_linkspeeds.csv")
        for setid in ['1','2','3']:
          loadVersion(Visum, "outputs/networks/tap_skim_initial.ver")
          loadLinkSpeeds(Visum, "outputs/networks/taz_skim_" + tp + "_speed_linkspeeds.csv")
          loadProcedure(Visum, "config/visum/tap_skim_speed_" + tp + ".xml")
          loadProcedure(Visum, "config/visum/tap_skim_" + tp + "_set" + setid + ".xml")
          saveVersion(Visum, "outputs/networks/tap_skim_" + tp + "_speed_set" + setid + ".ver")
          updateFareSkim(Visum, "outputs/skims/fare.omx", "fare", 
            "outputs/skims/tap_skim_" + tp + "_set" + setid + ".omx", "6")
        reviseDuplicateSkims(Visum, "outputs/skims/tap_skim_" + tp + "_set1.omx", 
          "outputs/skims/tap_skim_" + tp + "_set2.omx", "outputs/skims/tap_skim_" + tp + "_set3.omx")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)

  if runmode == 'tap_skim': #using modeled speeds and assign
    try:
      Visum = startVisum()
      for tp in ['ea','am','md','pm','ev']:
        loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
        saveLinkSpeeds(Visum, "outputs/networks/taz_skim_" + tp + "_speed_linkspeeds.csv")
        for setid in ['1','2','3']:
          loadVersion(Visum, "outputs/networks/tap_skim_" + tp + "_speed_set" + setid + ".ver")
          loadLinkSpeeds(Visum, "outputs/networks/taz_skim_" + tp + "_speed_linkspeeds.csv")
          loadProcedure(Visum, "config/visum/tap_skim_" + tp + ".xml")
          loadProcedure(Visum, "config/visum/tap_skim_" + tp + "_set" + setid + ".xml")
          saveVersion(Visum, "outputs/networks/tap_skim_" + tp + "_speed_set" + setid + ".ver")
          updateFareSkim(Visum, "outputs/skims/fare.omx", "fare", 
            "outputs/skims/tap_skim_" + tp + "_set" + setid + ".omx", "6")
        reviseDuplicateSkims(Visum, "outputs/skims/tap_skim_" + tp + "_set1.omx", 
          "outputs/skims/tap_skim_" + tp + "_set2.omx", "outputs/skims/tap_skim_" + tp + "_set3.omx")
      closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)
        
  if runmode == 'build_trip_matrices':
    
    #get hh sample rate for matrix expansion and global iteration number
    hhsamplerate = float(sys.argv[2].lower())
    iteration = int(sys.argv[3].lower())
    
    #build ct-ramp trip matrices
    tripFileName = "outputs/other/indivTripData_" + str(iteration) + ".csv"
    jtripFileName = "outputs/other/jointTripData_" + str(iteration) + ".csv"
    
    Visum = startVisum()
    loadVersion(Visum, "outputs/networks/taz_skim_am_speed.ver")
    buildTripMatrices(Visum, tripFileName, jtripFileName, hhsamplerate, "outputs/skims/tap_data.csv", 
      "outputs/trips/ctrampTazTrips.omx", "outputs/trips/ctrampTapTrips.omx", "outputs/trips/tapParks.csv")
    closeVisum(Visum)
    
    #load trip matrices
    for tp in ['ea','am','md','pm','ev']:
      #taz
      loadVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
      loadTripMatrices(Visum, "outputs/trips", tp, "taz")
      saveVersion(Visum, "outputs/networks/taz_skim_" + tp + "_speed.ver")
      
      #tap set
      for setid in ['1','2','3']:
        loadVersion(Visum, "outputs/networks/tap_skim_" + tp + "_speed_set" + setid + ".ver")
        loadTripMatrices(Visum, "outputs/trips", tp, "tap", setid)
        saveVersion(Visum, "outputs/networks/tap_skim_" + tp + "_speed_set" + setid + ".ver")  
    closeVisum(Visum)
    except Exception as e:
      print(runmode + " Failed")
      print(e)
      sys.exit(1)
    
  print("end model run: " + time.ctime())

