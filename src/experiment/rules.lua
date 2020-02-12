-- just as a reminder {black = 0, pink = 1, orange = 2, green = 3, blue = 4}

local rules = {}
rules.list = {
   {
      rule_type = 'place',
      structure = {
         {
            index = vector3(0, 0, 0),
            type = 0
         }
      },
      light = "left",
      target = {
         reference_index = vector3(0, 0, 0),
         offset_from_reference = vector3(0, 0, 1),
         type = 0
      },
      generate_orientations = false
   },
   -- {
   --    rule_type = 'place',
   --    structure = {
   --       {
   --          index = vector3(0, 0, 0),
   --          type = 0
   --       },
   --       {
   --          index = vector3(0, 0, 1),
   --          type = 0
   --       }
   --    },
   --    target = {
   --       reference_index = vector3(0, 0, 1),
   --       offset_from_reference = vector3(1, 0, -1),
   --       type = 0
   --    },
   --    generate_orientations = false
   -- },
   -- {
   --    rule_type = 'place',
   --    structure = {
   --       {
   --          index = vector3(0, 0, 1),
   --          type = 0
   --       },
   --       {
   --          index = vector3(-1, 0, 0),
   --          type = 0
   --       }
   --    },
   --    target = {
   --       reference_index = vector3(-1, 0, 0),
   --       offset_from_reference = vector3(0, 0, 1),
   --       type = 0
   --    },
   --    generate_orientations = false
   -- },
   -- {
   --    rule_type = 'place',
   --    structure = {
   --       {
   --          index = vector3(0, 0, 1),
   --          type = 0
   --       },
   --       {
   --          index = vector3(-1, 0, 1),
   --          type = 0
   --       },
   --       {
   --          index = vector3(-1, 0, 0),
   --          type = 0
   --       }
   --    },
   --    target = {
   --       reference_index = vector3(-1, 0, 1),
   --       offset_from_reference = vector3(1, 0, -1),
   --       type = 0
   --    },
   --    generate_orientations = false
   -- }
}
rules.selection_method = 'nearest_win'
return rules
