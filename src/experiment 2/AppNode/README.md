## Documents
### Process rules
This node is located in AppNode\_process\_rules.lua
#### Description
This node is passive (does not move the robot) unlike the rest of the nodes in the system.

It procesess `api.blocks` into groups of connected blocks, give the blocks unified indexes (those indexes describe the structure/substructure), matches the percieved structure with the rules (the rules are stored in a separate file, more of that later) and assigns a target\_block and offset if available.
#### Inputs/Outputs
- ##### rules list (input)
	This list is passed to the main controller as a parameter from .argos file. It contains all the rules necessary to do the required construction (full description of the file and how to right the rules later)
- ##### type (input)
	Takes `pickup/place`. It tells process rules which type of rules to look for. 
- ##### target (output)
	This table is passed to process_rules to be modified with the correct target.
	The target block is the reference block that the robot uses to reach target+offset.
    Target is not the final destination of the robot.
	- ###### target.reference\_id:
		contains the id of the target block. The id is compatible with the ids in `api.blocks`.
	- ###### target.offset:
		The offset from the target. target+offset determine the position of the block to be placed or picked up.
        The offset is represented based on the target block frame of reference, more of that in the rules description.
    - ###### target.color:
    	This represent the color which we need to set the block to before place or after pickup.
    - ###### target.safe:
    	If `true` then the rules has been matched safely and it is safe to continue with the action. But, if `false` then `process rules` is not sure of what it sees (some blocks might not be fully visible) and therefore, it is not safe/wise to continue with the action.
- ##### `api.blocks` this is not a parameter.
	process rules also uses the information of the blocks. 
#### How to roll with rules 
The rules file contains:
- ##### list of rules 
	to be matched against in process_rules.
    Each rule of the list contains:
    - ##### rule\_type
        `'pickup'/'place'`
    - ##### structure
        contains a list of blocks that form the structure/substructure. Each block of the list contains:
        - ###### index 
            It is a `vector3` that represents the position of the block with respect to the robot.
            When describing the index of the block, the robot is positioned just in front of the structure (the robot is positioned on the floor aligned with the structure). The indexes should follow the directions of the robots reference frame (shown later). The origin (0,0,0) of the indexes is to be defined by the rules writer and should be followed respectively by the user (if it is not clear, perhaps we should include some images from the presentation here)
        - ###### color 
            This represents the color of the block (it is an integer between 0 - 4)
    - ##### target
        - ###### reference_index 
            This represents the index of the target block which will be used by the robot as a reference while approaching target + offset
        - ###### offset_from_reference
            The offset from the target block. This offset + reference_index represents the final position of the block to be place or picked up.
        - ###### color
            color of the target to be set before placing the block or after pickup (probably it is better to put this in a separate field ¨actions¨)
    - ##### generate\_orientations
        Binary input. When `true`, process_rules generates 3 more orientations of this rule so that the total would be 4 rules representing the same structure description from all for points of view (if it is not clear, perhaps we should include some images from the presentation here). The generated rules are transparent to the upper layer. 
      
- ##### rules.selection\_method
	process rules offers two methods to select the winning rule in case more than one rule matches with the environment.
    Those methods (for the moment) are `'nearest_win'` and `'furthest_win'`.


##### Simple Example

```lua
local rules = {}
rules.list = {
   {
      rule_type = 'pickup',
      structure = {
         {
            index = vector3(0, 0, 0),
            color = 4
         }
      },
      target = {
         reference_index = vector3(0, 0, 0),
         offset_from_reference = vector3(0, 0, 0),
         color = 1
      },
      generate_orientations = false
   }
}
rules.selection_method = 'nearest_win'
return rules
```
#### Visualization
To demonstrate the results of process\_rules, we use two arrows. The red arrow points from the target block up. The blue arrow points from target+offset up.
In the case of pick up, there is only one arrow. 
Four green arrows mark the safe zone. All blocks that are found inside this zone are considered safe.  
#### Reference frames robot, block
- ##### Robots reference frame
	- X axis pointing forward
    - Y axis pointing to the left
    - Z axis pointing up
- ##### Camera reference frame
	- X axis pointing left
	- Y axis pointing down 
	- Z axis pointing far from the camera
- ##### Block reference frame
	Having the robot in front of the block, looking from the block to the robot
	- X axis pointing forward
	- Y axis pointing left
	- Z axis pointing up
- ##### Face reference frame
	So far it is not necessary for this module, might be in the future

#### Examples/tests
- ##### [basic test](https://github.com/freedomcondor/BuilderBotLibrary/blob/develop/testing/08_process_rules/01_basic_test.argos)
	This test is the simplest case possible for process_rules. In the environment we have one block only. The robot lifts up the manipulator and calls process_rules.
- ##### [colomn matching](https://github.com/freedomcondor/BuilderBotLibrary/blob/develop/testing/08_process_rules/02_colomn_matching_test.argos)
	In this test we have the robot situated in front of a column of 3 blocks of different colors:
    ```lua
    structure = {
             {
                index = vector3(0, 0, 0),
                color = 1
             },
             {
                index = vector3(0, 0, 1),
                color = 3
             },
             {
                index = vector3(0, 0, 2),
                color = 4
             }
          }
  	```
  The camera sees all blocks and tries to match the rules for each block. The rules would match for all three cases. Having the middle block in a safe zone reflects in having the final result as safe (shown in the terminal).
      The target block in this example is the middle block expressed as `reference_index = vector3(0, 0, 1)` in the `rules.lua` file and the `offset_from_reference = vector3(1, 0, -1))` which translates in the empty position in front of the first block.
- ##### [nearest target](https://github.com/freedomcondor/BuilderBotLibrary/blob/develop/testing/08_process_rules/03_nearest_target_test.argos)
- ##### [furthest target](https://github.com/freedomcondor/BuilderBotLibrary/blob/develop/testing/08_process_rules/04_furthest_target_test.argos)
- ##### [unalligned robot](https://github.com/freedomcondor/BuilderBotLibrary/blob/develop/testing/08_process_rules/05_unalligned_robot_test.argos)
	
### search
#### Description
Search makes robot randomly walk around and look for a block based on a user provided rule.

#### Inputs/Outputs
create\_search\_block\_node takes a process\_rule node as the parameter. It produces a node where robot randomly walks around with obstacle avoidance and looks for the target block.

#### Example
app.create\_search\_block\_node(
   app.create\_process\_rules\_node(rules, 'pickup', BTDATA.target)
),

### obstacle avoidance
#### Description
There during randomly walk, as well as approach, the robot checks its rangefinders when moving around. Currently the robot only checks the rangefinders infront. When it detects something, it will move backwards and turn 180 degree.

Currently the obstacle avoidance is hard coded inside search node and approach node. The user doesn't have to do anything.

### approach
#### Description
There are two basic approach method is provided, Z shape approach and curved approach.
Z shape approach makes the robot first analyzes the location of the target block, and close the camera and perform a rotation-forward-rotation action to a location which is just in front of the target block with a distance which is given as a parameter.

Curved approach makes the robot approach the block while keep the block in the range of its camera. The robot will move forward and backward in turns until it gets the location right in front of the block with the distance given as the second parameter.

We also provide a combination of this two approach, simply called approach. In approach node, the robot will first analize the location of the block. If it is close enough, robot will perform curved approach, if not, the robot will first perform z shape approach, and then curved approach. But the user has to provide a search node, because after z shape approach, the robot will lost block and search again.

#### Inputs/Outputs
create\_Z\_shape\_approach\_node and create\_curved\_approach\_node take a target block (a table {reference\_id}) and a distance as paramete. 
create\_approach\_node takes search\_node, a target block and a distance as parameters.

#### Example
See examples of pickup and place block.

### pickup and place block
Pickup node is located in AppNode/create\_pickup\_block\_node.lua
Place node is located in AppNode/create\_place\_block\_node.lua

#### Description
Pickup node assumes the robot is right in front of the target block at a certain distance (this distance is provided by user). The robot will perform the following action: 1. The robot charges the electromagnets and moves forward blindly until its manipulator is right on top of the target block. 2. The robot lowers its manipulator until the manipulator touches the block. 3. The robot discharge the electromagnets as "construction mode". 4. The robot raise the manipulator with the block attached.

Place node is very similiar to pickup node. Instead of going for the target block directly, the robot takes the target block as a reference, and goes for a virtual block according to a offset. The electromagnet also discharges as "destruction" mode.

The offset is a vector3. vector3(0,0,1) means the robot needs to put the block on top of the reference block. vector3(1,0,0) means the robot needs to put the block in front of the reference block.

#### Inputs/Outputs
Both node creation functions takes two parameters, a table containing an offset, and a distance. See the example for details.

#### Example
```lua
bt.create{
	type = "sequence*",
	children = 
	{
		app.create_approach_node({reference_id = 1, offset = vector3(0,0,0),}, 0.18),
		app.create_pickup_block_node({reference_id = 1, offset = vector3(0,0,0),}, 0.18),

		app.create_approach_node({reference_id = 2, offset = vector3(0,0,1),}, 0.18),
		app.create_place_block_node({reference_id = 2, offset = vector3(0,0,1),}, 0.18),
	},
}
```

In this case, the robot will first approach block No.1 until the distance is 18cm, and then move forward and pickup block No.1. Then the robot will approach block No.2 until the distance is 18cm, and then move forward an put block No.1 on top of block No.2.

### timer
This node is located in AppNode/create\_timer\_node.lua
#### Description
This node will count a period of time. For each step during this time, a user defined function can be run.

#### Inputs/Outputs
To create this node, a table is taken as parameter. The table is like
```lua
{
	time = 4, 
	func = function() print("I am a step") end,
}
```
The unit of time is second. func can be nil. The return value of func doesn't matter

The output of timer is a bt node which will return running when counting, and return true when time is up.

#### Example
```lua
bt.create{
	type = "sequence*",
	children = {
		function() print("start") return false true end,
		app.create_timer_node{time = 5, func = function() print("step") end,},
		function() print("end") return false true end,
	},
}
```
In this case, the bt will print "start", and then print "step" each step for 5 seconds and then print "end".


